defmodule PremiereEcouteWeb.Playlists.SubmissionLive do
  @moduledoc """
  Viewer track submission LiveView.

  Lets authenticated viewers search Spotify for tracks and add them directly to a
  streamer's open playlist. Resolves the playlist by its Spotify ID, not by the
  current user's library, since viewers do not own the playlist.
  """

  use PremiereEcouteWeb, :live_view

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Playlists.LibraryPlaylist.Submission

  @impl true
  def mount(%{"id" => playlist_id}, _session, socket) do
    library_playlist = LibraryPlaylist.get_by(playlist_id: playlist_id)

    viewer = socket.assigns.current_scope.user

    cond do
      is_nil(library_playlist) ->
        {:ok, redirect(socket, to: ~p"/")}

      not PremiereEcouteCore.FeatureFlag.enabled?(:playlist_submissions, for: viewer) ->
        {:ok, redirect(socket, to: ~p"/")}

      not LibraryPlaylist.submission_page_enabled?(library_playlist) ->
        {:ok, redirect(socket, to: ~p"/")}

      true ->
        streamer = Accounts.get_user!(library_playlist.user_id)
        {tracks, submitters} = load_playlist_data(library_playlist)

        {:ok,
         socket
         |> assign(:library_playlist, library_playlist)
         |> assign(:streamer, streamer)
         |> assign(:viewer, viewer)
         |> assign(:viewer_submissions, Submission.list_for_viewer(library_playlist, viewer))
         |> assign(:submissions_count, Submission.count_for_viewer(library_playlist, viewer))
         |> assign(:search_form, to_form(%{"query" => ""}))
         |> assign(:search_results, AsyncResult.ok([]))
         |> assign(:selected_track, nil)
         |> assign(:submitting, false)
         |> assign(:error, nil)
         |> assign(:success, nil)
         |> assign(:tracks, tracks)
         |> assign(:submitters, submitters)}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) when byte_size(query) > 2 do
    socket
    |> assign(:search_results, AsyncResult.loading())
    |> assign(:selected_track, nil)
    |> start_async(:search, fn -> Apis.spotify().search_any_track(query) end)
    |> then(&{:noreply, &1})
  end

  def handle_event("search", _params, socket) do
    {:noreply, assign(socket, :search_results, AsyncResult.ok([]))}
  end

  @impl true
  def handle_event("clear_search_results", _params, socket) do
    {:noreply, assign(socket, :search_results, AsyncResult.ok([]))}
  end

  @impl true
  def handle_event("select_track", %{"track_id" => track_id}, socket) do
    track =
      case socket.assigns.search_results do
        %{result: tracks} when is_list(tracks) ->
          Enum.find(tracks, &(Map.get(&1.provider_ids, :spotify) == track_id))

        _ ->
          nil
      end

    socket
    |> assign(:selected_track, track)
    |> assign(:search_results, AsyncResult.ok([]))
    |> assign(:error, nil)
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_event("clear_selected_track", _params, socket) do
    {:noreply, assign(socket, :selected_track, nil)}
  end

  @impl true
  def handle_event("delete_submission", %{"provider_id" => provider_id}, socket) do
    %{library_playlist: playlist, viewer: viewer} = socket.assigns

    {:noreply,
     socket
     |> assign(:error, nil)
     |> start_async({:delete_submission, provider_id}, fn ->
       do_delete_submission(playlist, viewer, provider_id)
     end)}
  end

  @impl true
  def handle_event("submit_track", _params, socket) do
    %{library_playlist: playlist, selected_track: track, viewer: viewer, submissions_count: count} = socket.assigns
    limit = LibraryPlaylist.submission_limit(playlist)

    cond do
      is_nil(track) ->
        {:noreply, assign(socket, :error, gettext("Please select a track first."))}

      not LibraryPlaylist.submissions_open?(playlist) ->
        {:noreply, assign(socket, :error, gettext("Submissions are currently closed."))}

      count >= limit ->
        {:noreply,
         assign(
           socket,
           :error,
           ngettext(
             "You have reached the limit of %{count} submission for this playlist.",
             "You have reached the limit of %{count} submissions for this playlist.",
             limit,
             count: limit
           )
         )}

      true ->
        {:noreply,
         socket
         |> assign(:submitting, true)
         |> assign(:error, nil)
         |> start_async(:submit, fn -> do_submit(playlist, track, viewer) end)}
    end
  end

  @impl true
  def handle_async(:search, {:ok, {:ok, tracks}}, socket) do
    {:noreply, assign(socket, :search_results, AsyncResult.ok(tracks))}
  end

  def handle_async(:search, {:ok, {:error, _}}, socket) do
    {:noreply,
     socket
     |> assign(:search_results, AsyncResult.failed(socket.assigns.search_results, :error))
     |> assign(:error, gettext("Search failed. Please try again."))}
  end

  def handle_async(:search, {:exit, _}, socket) do
    {:noreply,
     socket
     |> assign(:search_results, AsyncResult.failed(socket.assigns.search_results, :error))
     |> assign(:error, gettext("Search failed. Please try again."))}
  end

  def handle_async(:submit, {:ok, :submissions_closed}, socket) do
    {:noreply,
     socket
     |> assign(:submitting, false)
     |> assign(:error, gettext("Submissions are currently closed."))}
  end

  def handle_async(:submit, {:ok, :quota_exceeded}, socket) do
    %{library_playlist: playlist} = socket.assigns
    limit = LibraryPlaylist.submission_limit(playlist)

    {:noreply,
     socket
     |> assign(:submitting, false)
     |> assign(
       :error,
       ngettext(
         "You have reached the limit of %{count} submission for this playlist.",
         "You have reached the limit of %{count} submissions for this playlist.",
         limit,
         count: limit
       )
     )}
  end

  def handle_async(:submit, {:ok, :duplicate}, socket) do
    {:noreply,
     socket
     |> assign(:submitting, false)
     |> assign(:error, gettext("This track is already in the playlist."))}
  end

  def handle_async(:submit, {:ok, {:ok, provider_id}}, socket) do
    %{library_playlist: playlist, viewer: viewer} = socket.assigns
    {:ok, _} = Submission.create(playlist, viewer, provider_id)
    {tracks, submitters} = load_playlist_data(playlist)

    {:noreply,
     socket
     |> assign(:submitting, false)
     |> assign(:selected_track, nil)
     |> assign(:search_form, to_form(%{"query" => ""}))
     |> assign(:viewer_submissions, Submission.list_for_viewer(playlist, viewer))
     |> assign(:submissions_count, socket.assigns.submissions_count + 1)
     |> assign(:tracks, tracks)
     |> assign(:submitters, submitters)
     |> assign(:success, gettext("Track added to the playlist!"))}
  end

  def handle_async(:submit, {:ok, {:error, _}}, socket) do
    {:noreply,
     socket
     |> assign(:submitting, false)
     |> assign(:error, gettext("Failed to add track. Please try again."))}
  end

  def handle_async(:submit, {:exit, _}, socket) do
    {:noreply,
     socket
     |> assign(:submitting, false)
     |> assign(:error, gettext("Failed to add track. Please try again."))}
  end

  def handle_async({:delete_submission, _provider_id}, {:ok, {:ok, playlist_data}}, socket) do
    %{library_playlist: playlist, viewer: viewer} = socket.assigns
    {tracks, submitters} = playlist_data

    {:noreply,
     socket
     |> assign(:viewer_submissions, Submission.list_for_viewer(playlist, viewer))
     |> assign(:submissions_count, Submission.count_for_viewer(playlist, viewer))
     |> assign(:tracks, tracks)
     |> assign(:submitters, submitters)
     |> assign(:success, gettext("Track removed from the playlist."))}
  end

  def handle_async({:delete_submission, _provider_id}, {:ok, {:error, _}}, socket) do
    {:noreply, assign(socket, :error, gettext("Failed to remove track. Please try again."))}
  end

  def handle_async({:delete_submission, _provider_id}, {:exit, _}, socket) do
    {:noreply, assign(socket, :error, gettext("Failed to remove track. Please try again."))}
  end

  # Fetches current playlist tracks from Spotify, checks for duplicate, then adds.
  # Returns {:ok, provider_id} | :duplicate | :quota_exceeded | :submissions_closed | {:error, term}
  # AIDEV-NOTE: Single has no provider/2 — wraps spotify ID in Album.Track which does,
  # since add_items_to_playlist only needs the ID via track_id/1.
  # Re-fetches library_playlist and count from DB to avoid stale mount-time snapshot
  # (submissions_open? toggled by streamer, or quota raced from multiple tabs).
  defp do_submit(playlist, single, viewer) do
    track_spotify_id = Map.get(single.provider_ids, :spotify)
    fresh_playlist = LibraryPlaylist.get_by(id: playlist.id)
    fresh_count = Submission.count_for_viewer(fresh_playlist, viewer)
    limit = LibraryPlaylist.submission_limit(fresh_playlist)

    cond do
      not LibraryPlaylist.submissions_open?(fresh_playlist) ->
        :submissions_closed

      fresh_count >= limit ->
        :quota_exceeded

      true ->
        streamer_scope = build_streamer_scope(playlist.user_id)
        api_track = %Album.Track{provider_ids: %{spotify: track_spotify_id}}

        with {:ok, current_playlist} <- Apis.spotify().get_playlist(playlist.playlist_id),
             false <- track_already_present?(current_playlist.tracks, track_spotify_id),
             {:ok, _} <- Apis.spotify().add_items_to_playlist(streamer_scope, playlist.playlist_id, [api_track]) do
          {:ok, track_spotify_id}
        else
          true -> :duplicate
          {:error, _} = err -> err
        end
    end
  end

  # Removes track from Spotify first (if still present), then deletes the submission record.
  # Order matters: if the Spotify call fails, the DB record is preserved so the viewer retains
  # their submission slot and can retry. Returns {:ok, playlist_data} | {:error, term}.
  defp do_delete_submission(playlist, viewer, provider_id) do
    streamer_scope = build_streamer_scope(playlist.user_id)
    api_track = %Album.Track{provider_ids: %{spotify: provider_id}}

    spotify_result =
      case Apis.spotify().get_playlist(playlist.playlist_id) do
        {:ok, current_playlist} ->
          if track_already_present?(current_playlist.tracks, provider_id) do
            Apis.spotify().remove_playlist_items(streamer_scope, playlist.playlist_id, [api_track])
          else
            :ok
          end

        {:error, _} = err ->
          err
      end

    with :ok <- spotify_result,
         {:ok, _} <- Submission.delete_for_viewer(playlist, viewer, provider_id) do
      {:ok, load_playlist_data(playlist)}
    end
  end

  defp track_already_present?(tracks, spotify_id) do
    Enum.any?(tracks, fn t -> t.track_id == spotify_id end)
  end

  defp build_streamer_scope(user_id) do
    user =
      user_id
      |> Accounts.get_user!()
      |> Accounts.preload_user()

    Scope.for_user(user)
  end

  # AIDEV-NOTE: get_playlist uses client credentials; streamer token only needed for writes.
  # Reconciliation always runs regardless of show_tracks_to_viewers? so stale submission
  # records are cleaned up even when the track list is hidden from viewers.
  # @tracks always holds the full list; the template gates display on show_tracks_to_viewers?.
  # Returns {tracks_or_nil, submitters_map}.
  defp load_playlist_data(playlist) do
    case Apis.spotify().get_playlist(playlist.playlist_id) do
      {:ok, p} ->
        live_ids = Enum.map(p.tracks, & &1.track_id)
        Submission.delete_stale(playlist, live_ids)
        submitters = Submission.submitters_map(playlist)
        {p.tracks, submitters}

      _ ->
        {nil, %{}}
    end
  end
end
