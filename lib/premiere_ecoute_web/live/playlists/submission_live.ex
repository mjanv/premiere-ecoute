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

  @impl true
  def mount(%{"id" => playlist_id}, _session, socket) do
    library_playlist = LibraryPlaylist.get_by(playlist_id: playlist_id)

    cond do
      is_nil(library_playlist) ->
        {:ok, redirect(socket, to: ~p"/")}

      not LibraryPlaylist.submission_page_enabled?(library_playlist) ->
        {:ok, redirect(socket, to: ~p"/")}

      true ->
        streamer = Accounts.get_user!(library_playlist.user_id)

        {:ok,
         socket
         |> assign(:library_playlist, library_playlist)
         |> assign(:streamer, streamer)
         |> assign(:search_form, to_form(%{"query" => ""}))
         |> assign(:search_results, AsyncResult.ok([]))
         |> assign(:selected_track, nil)
         |> assign(:submitting, false)
         |> assign(:error, nil)
         |> assign(:success, nil)
         |> assign(:tracks, load_playlist_tracks(library_playlist))}
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
  def handle_event("submit_track", _params, socket) do
    %{library_playlist: playlist, selected_track: track} = socket.assigns

    cond do
      is_nil(track) ->
        {:noreply, assign(socket, :error, gettext("Please select a track first."))}

      not LibraryPlaylist.submissions_open?(playlist) ->
        {:noreply, assign(socket, :error, gettext("Submissions are currently closed."))}

      true ->
        {:noreply,
         socket
         |> assign(:submitting, true)
         |> assign(:error, nil)
         |> start_async(:submit, fn -> do_submit(playlist, track) end)}
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

  def handle_async(:submit, {:ok, :duplicate}, socket) do
    {:noreply,
     socket
     |> assign(:submitting, false)
     |> assign(:error, gettext("This track is already in the playlist."))}
  end

  def handle_async(:submit, {:ok, :ok}, socket) do
    # Reload playlist tracks so the updated list is shown if show_tracks_to_viewers is on
    updated_tracks = load_playlist_tracks(socket.assigns.library_playlist)

    {:noreply,
     socket
     |> assign(:submitting, false)
     |> assign(:selected_track, nil)
     |> assign(:search_form, to_form(%{"query" => ""}))
     |> assign(:tracks, updated_tracks)
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

  # Fetches current playlist tracks from Spotify, checks for duplicate, then adds.
  # Returns :ok | :duplicate | {:error, term}
  # AIDEV-NOTE: Single has no provider/2 — wraps spotify ID in Album.Track which does,
  # since add_items_to_playlist only needs the ID via track_id/1.
  defp do_submit(playlist, single) do
    track_spotify_id = Map.get(single.provider_ids, :spotify)
    streamer_scope = build_streamer_scope(playlist.user_id)
    api_track = %Album.Track{provider_ids: %{spotify: track_spotify_id}}

    with {:ok, current_playlist} <- Apis.spotify().get_playlist(playlist.playlist_id),
         false <- track_already_present?(current_playlist.tracks, track_spotify_id),
         {:ok, _} <- Apis.spotify().add_items_to_playlist(streamer_scope, playlist.playlist_id, [api_track]) do
      :ok
    else
      true -> :duplicate
      {:error, _} = err -> err
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
  # Returns nil when show_tracks_to_viewers is off so the template skips the track list.
  defp load_playlist_tracks(playlist) do
    if LibraryPlaylist.show_tracks_to_viewers?(playlist) do
      case Apis.spotify().get_playlist(playlist.playlist_id) do
        {:ok, p} -> p.tracks
        _ -> nil
      end
    end
  end
end
