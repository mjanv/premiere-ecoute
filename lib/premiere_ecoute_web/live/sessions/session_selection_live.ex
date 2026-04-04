defmodule PremiereEcouteWeb.Sessions.SessionSelectionLive do
  @moduledoc """
  Album/playlist/track selection LiveView for session creation.

  Provides interface to search Spotify albums or select user playlists asynchronously, configure vote options (0-10, 1-5, smash/pass), and create new listening sessions with selected content.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Sessions.Components.SessionSelectionComponents

  alias Phoenix.LiveView.AsyncResult
  alias PremiereEcoute.Sessions.AlbumPicks
  alias PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:source_type, nil)
    |> assign(:search_form, to_form(%{"query" => ""}))
    |> assign(:search_albums, AsyncResult.ok([]))
    |> assign(:selected_album, AsyncResult.ok(nil))
    |> assign(:user_playlists, AsyncResult.ok([]))
    |> assign(:selected_playlist, AsyncResult.ok(nil))
    |> assign(:search_tracks, AsyncResult.ok([]))
    |> assign(:selected_track, AsyncResult.ok(nil))
    |> assign(:current_scope, socket.assigns[:current_scope] || %{})
    |> assign(:vote_options_preset, nil)
    |> assign(:vote_options_configured, false)
    |> assign(:show_random_modal, false)
    |> assign(:picks_empty, true)
    |> assign(:random_pick, nil)
    |> assign(:pick_spinning, false)
    |> assign(:free_session_name, "")
    |> assign(:free_vote_mode, nil)
    |> update_state()
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event("search_albums", %{"query" => query}, socket) when byte_size(query) > 2 do
    socket
    |> assign(:search_albums, AsyncResult.loading())
    |> start_async(:search, fn -> PremiereEcoute.Apis.spotify().search_albums(query) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("search_albums", _params, socket) do
    # Clear search results when query is empty or too short
    socket
    |> assign(:search_albums, AsyncResult.ok([]))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("clear_search_results", _params, socket) do
    socket
    |> assign(:search_albums, AsyncResult.ok([]))
    |> assign(:search_tracks, AsyncResult.ok([]))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("fetch_currently_playing", _params, socket) do
    scope = socket.assigns.current_scope

    socket
    |> assign(:selected_track, AsyncResult.loading())
    |> start_async(:select_track, fn ->
      case PremiereEcoute.Apis.spotify().get_playback_state(scope, %{}) do
        {:ok, %{"item" => item, "currently_playing_type" => "track"}} when not is_nil(item) ->
          PremiereEcoute.Apis.spotify().get_single(item["id"])

        _ ->
          {:error, :nothing_playing}
      end
    end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("search_tracks", %{"query" => query}, socket) when byte_size(query) > 2 do
    socket
    |> assign(:search_tracks, AsyncResult.loading())
    |> start_async(:search_tracks, fn -> PremiereEcoute.Apis.spotify().search_singles(query) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("search_tracks", _params, socket) do
    socket
    |> assign(:search_tracks, AsyncResult.ok([]))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("select_track", %{"track_id" => track_id}, socket) do
    case socket.assigns.search_tracks do
      %{result: tracks} when is_list(tracks) ->
        case Enum.find(tracks, fn t -> Map.get(t.provider_ids, :spotify) == track_id end) do
          nil ->
            socket
            |> assign(:search_tracks, AsyncResult.ok([]))
            |> assign(:selected_track, AsyncResult.loading())
            |> start_async(:select_track, fn -> PremiereEcoute.Apis.spotify().get_single(track_id) end)

          track ->
            socket
            |> assign(:search_tracks, AsyncResult.ok([]))
            |> assign(:selected_track, AsyncResult.ok(track))
            |> update_state()
        end

      _ ->
        socket
        |> assign(:search_tracks, AsyncResult.ok([]))
        |> assign(:selected_track, AsyncResult.loading())
        |> start_async(:select_track, fn -> PremiereEcoute.Apis.spotify().get_single(track_id) end)
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("select_source", %{"source" => source}, socket) do
    socket
    |> assign(:source_type, source)
    # Clear previous searches
    |> assign(:search_albums, AsyncResult.ok([]))
    |> assign(:search_tracks, AsyncResult.ok([]))
    # Clear previous selection
    |> assign(:selected_album, AsyncResult.ok(nil))
    |> assign(:selected_playlist, AsyncResult.ok(nil))
    |> assign(:selected_track, AsyncResult.ok(nil))
    # Reset search form
    |> assign(:search_form, to_form(%{"query" => ""}))
    # Reset vote options state
    |> assign(:vote_options_preset, nil)
    |> assign(:vote_options_configured, false)
    |> assign(:free_vote_mode, nil)
    # Load playlists if playlist source is selected
    |> maybe_load_playlists(source)
    |> update_state()
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("select_album", %{"album_id" => album_id}, socket) do
    socket
    |> assign(:search_albums, AsyncResult.ok([]))
    |> assign(:selected_album, AsyncResult.loading())
    |> start_async(:select, fn -> PremiereEcoute.Apis.spotify().get_album(album_id) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("select_playlist", %{"playlist_id" => ""}, socket) do
    # Clear selection when empty value is selected
    socket
    |> assign(:selected_playlist, AsyncResult.ok(nil))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("select_playlist", %{"playlist_id" => playlist_id}, socket) do
    # Find the library playlist from the loaded playlists
    case socket.assigns.user_playlists do
      %{result: playlists} when is_list(playlists) ->
        case Enum.find(playlists, fn p -> p.playlist_id == playlist_id end) do
          nil ->
            socket
            |> assign(:selected_playlist, AsyncResult.failed(socket.assigns.selected_playlist, {:error, "Playlist not found"}))
            |> put_flash(:error, "Playlist not found")
            |> then(fn socket -> {:noreply, socket} end)

          playlist ->
            socket
            |> assign(:selected_playlist, AsyncResult.ok(playlist))
            |> update_state()
            |> then(fn socket -> {:noreply, socket} end)
        end

      _ ->
        socket
        |> assign(:selected_playlist, AsyncResult.failed(socket.assigns.selected_playlist, {:error, "No playlists loaded"}))
        |> put_flash(:error, "Please select playlist source first")
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_event(
        "prepare_session",
        _params,
        %{assigns: %{selected_track: %{result: track}}} = socket
      )
      when not is_nil(track) do
    %PrepareListeningSession{
      source: :track,
      user_id: get_user_id(socket),
      track_id: Map.get(track.provider_ids, :spotify),
      vote_options: get_vote_options(socket.assigns)
    }
    |> PremiereEcoute.apply()
    |> case do
      {:ok, session, _} -> push_navigate(socket, to: ~p"/sessions/#{session}/dashboard")
      {:error, _} -> put_flash(socket, :error, "Cannot create the listening session")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("prepare_session", _params, %{assigns: %{source_type: "free"}} = socket) do
    %PrepareListeningSession{
      source: :free,
      user_id: get_user_id(socket),
      name: socket.assigns.free_session_name,
      vote_options: get_vote_options(socket.assigns),
      vote_mode: String.to_existing_atom(socket.assigns.free_vote_mode)
    }
    |> PremiereEcoute.apply()
    |> case do
      {:ok, session, _} -> push_navigate(socket, to: ~p"/sessions/#{session}/dashboard")
      {:error, _} -> put_flash(socket, :error, gettext("Cannot create the listening session"))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("prepare_session", _params, %{assigns: %{selected_album: nil, selected_playlist: %{result: nil}}} = socket) do
    {:noreply, put_flash(socket, :error, "Please select an album or playlist first")}
  end

  def handle_event("vote_options_preset_change", %{"preset" => preset}, socket) do
    case preset do
      "" ->
        # Handle empty selection - don't mark as configured
        socket
        |> assign(:vote_options_preset, nil)
        |> assign(:vote_options_configured, false)
        |> update_state()
        |> then(fn socket -> {:noreply, socket} end)

      _ ->
        opts = get_vote_options(%{vote_options_preset: preset})
        # Reset poll vote_mode if switching to >5 options (poll no longer allowed)
        free_vote_mode =
          if socket.assigns.free_vote_mode == "poll" && length(opts) > 5, do: nil, else: socket.assigns.free_vote_mode

        socket
        |> assign(:vote_options_preset, preset)
        |> assign(:vote_options_configured, true)
        |> assign(:free_vote_mode, free_vote_mode)
        |> update_state()
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_event(
        "prepare_session",
        _params,
        %{assigns: %{selected_album: %{result: album}}} = socket
      )
      when not is_nil(album) do
    vote_options = get_vote_options(socket.assigns)

    %PrepareListeningSession{
      source: :album,
      user_id: get_user_id(socket),
      album_id: Map.get(album.provider_ids, :spotify),
      vote_options: vote_options
    }
    |> PremiereEcoute.apply()
    |> case do
      {:ok, session, _} -> push_navigate(socket, to: ~p"/sessions/#{session}/dashboard")
      {:error, _} -> put_flash(socket, :error, "Cannot create the listening session")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event(
        "prepare_session",
        _params,
        %{assigns: %{selected_playlist: %{result: playlist}}} = socket
      )
      when not is_nil(playlist) do
    %PrepareListeningSession{
      source: :playlist,
      user_id: get_user_id(socket),
      playlist_id: playlist.playlist_id,
      vote_options: get_vote_options(socket.assigns)
    }
    |> PremiereEcoute.apply()
    |> case do
      {:ok, session, _} -> push_navigate(socket, to: ~p"/sessions/#{session}/dashboard")
      {:error, _} -> put_flash(socket, :error, "Cannot create the listening session")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("update_free_session_name", %{"name" => name}, socket) do
    {:noreply, socket |> assign(:free_session_name, name) |> update_state()}
  end

  def handle_event("select_free_vote_mode", %{"mode" => mode}, socket) do
    {:noreply, socket |> assign(:free_vote_mode, mode) |> update_state()}
  end

  def handle_event("open_random_modal", _params, socket) do
    user_id = get_user_id(socket)

    socket
    |> assign(:show_random_modal, true)
    |> assign(:random_pick, nil)
    |> assign(:pick_spinning, false)
    |> assign(:picks_empty, AlbumPicks.count_for_user(user_id) == 0)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("close_random_modal", _params, socket) do
    socket
    |> assign(:show_random_modal, false)
    |> assign(:random_pick, nil)
    |> assign(:pick_spinning, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("spin_wheel", _params, socket) do
    user_id = get_user_id(socket)

    socket
    |> assign(:pick_spinning, true)
    |> assign(:random_pick, nil)
    |> start_async(:spin_wheel, fn ->
      Process.sleep(2000)
      AlbumPicks.random_entry(user_id)
    end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("use_random_album", _params, socket) do
    case socket.assigns.random_pick do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("No album selected"))}

      pick ->
        socket
        |> assign(:show_random_modal, false)
        |> assign(:random_pick, nil)
        |> assign(:pick_spinning, false)
        |> assign(:selected_album, AsyncResult.loading())
        |> start_async(:select, fn -> PremiereEcoute.Apis.spotify().get_album(pick.album_id) end)
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  @impl true
  def handle_async(:search, {:ok, result}, %{assigns: assigns} = socket) do
    case result do
      {:ok, albums} ->
        socket
        |> assign(:search_albums, AsyncResult.ok(albums))

      {:error, reason} ->
        socket
        |> assign(:search_albums, AsyncResult.failed(assigns.search_albums, {:error, reason}))
        |> put_flash(:error, "Search failed. Please try again.")
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:search, {:exit, reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:search_albums, AsyncResult.failed(assigns.search_albums, {:error, reason}))
    |> put_flash(:error, "Search failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select, {:ok, {:ok, album}}, socket) do
    socket
    |> assign(:selected_album, AsyncResult.ok(album))
    |> update_state()
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select, {:ok, {:error, reason}}, %{assigns: assigns} = socket) do
    socket
    |> assign(:selected_album, AsyncResult.failed(assigns.selected_album, {:error, reason}))
    |> put_flash(:error, "Selection failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select, {:exit, reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:selected_album, AsyncResult.failed(assigns.selected_album, {:error, reason}))
    |> put_flash(:error, "Selection failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:search_tracks, {:ok, {:ok, tracks}}, socket) do
    socket
    |> assign(:search_tracks, AsyncResult.ok(tracks))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:search_tracks, {:ok, {:error, reason}}, %{assigns: assigns} = socket) do
    socket
    |> assign(:search_tracks, AsyncResult.failed(assigns.search_tracks, {:error, reason}))
    |> put_flash(:error, "Track search failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:search_tracks, {:exit, reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:search_tracks, AsyncResult.failed(assigns.search_tracks, {:error, reason}))
    |> put_flash(:error, "Track search failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select_track, {:ok, {:ok, track}}, socket) do
    socket
    |> assign(:selected_track, AsyncResult.ok(track))
    |> update_state()
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select_track, {:ok, {:error, :nothing_playing}}, socket) do
    socket
    |> assign(:selected_track, AsyncResult.ok(nil))
    |> put_flash(:info, gettext("No track currently playing on Spotify."))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select_track, {:ok, {:error, reason}}, %{assigns: assigns} = socket) do
    socket
    |> assign(:selected_track, AsyncResult.failed(assigns.selected_track, {:error, reason}))
    |> put_flash(:error, "Track selection failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:select_track, {:exit, reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:selected_track, AsyncResult.failed(assigns.selected_track, {:error, reason}))
    |> put_flash(:error, "Track selection failed. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:load_playlists, {:ok, {:ok, playlists}}, socket) do
    socket
    |> assign(:user_playlists, AsyncResult.ok(playlists))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:load_playlists, {:ok, {:error, reason}}, %{assigns: assigns} = socket) do
    socket
    |> assign(:user_playlists, AsyncResult.failed(assigns.user_playlists, {:error, reason}))
    |> put_flash(:error, "Failed to load playlists. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:load_playlists, {:exit, reason}, %{assigns: assigns} = socket) do
    socket
    |> assign(:user_playlists, AsyncResult.failed(assigns.user_playlists, {:error, reason}))
    |> put_flash(:error, "Failed to load playlists. Please try again.")
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:spin_wheel, {:ok, nil}, socket) do
    socket
    |> assign(:pick_spinning, false)
    |> assign(:random_pick, nil)
    |> put_flash(:info, gettext("No albums in the pick list yet!"))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:spin_wheel, {:ok, pick}, socket) do
    socket
    |> assign(:pick_spinning, false)
    |> assign(:random_pick, pick)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:spin_wheel, {:exit, _reason}, socket) do
    socket
    |> assign(:pick_spinning, false)
    |> put_flash(:error, gettext("Spin failed. Please try again."))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @doc """
  Returns vote options list based on preset configuration.

  Maps preset identifiers (0-10, 1-5, smash-pass) to their corresponding vote option arrays for session configuration.
  """
  @spec get_vote_options(map()) :: [String.t()]
  def get_vote_options(%{vote_options_preset: "0-10"}), do: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
  def get_vote_options(%{vote_options_preset: "1-5"}), do: ["1", "2", "3", "4", "5"]
  def get_vote_options(%{vote_options_preset: "smash-pass"}), do: ["smash", "pass"]
  def get_vote_options(%{vote_options_preset: nil}), do: []

  # default fallback - return empty for any other case
  def get_vote_options(_), do: []

  defp get_user_id(socket) do
    case socket.assigns.current_scope do
      %{user: %{id: user_id}} -> user_id
      _ -> nil
    end
  end

  defp maybe_load_playlists(socket, "playlist") do
    case socket.assigns.current_scope do
      %{user: user} ->
        socket
        |> assign(:user_playlists, AsyncResult.loading())
        |> start_async(:load_playlists, fn -> {:ok, PremiereEcoute.Playlists.all_for_user(user)} end)

      _ ->
        socket
        |> assign(:user_playlists, AsyncResult.failed(socket.assigns.user_playlists, {:error, "No authentication"}))
        |> put_flash(:error, "Please authenticate to view your playlists")
    end
  end

  defp maybe_load_playlists(socket, _), do: socket

  defp update_state(socket) do
    %{
      source_type: source_type,
      selected_album: selected_album,
      selected_playlist: selected_playlist,
      selected_track: selected_track,
      free_session_name: free_session_name,
      vote_options_configured: vote_options_configured,
      free_vote_mode: free_vote_mode
    } = socket.assigns

    content_selected =
      (source_type == "album" && selected_album.ok? && selected_album.result) ||
        (source_type == "playlist" && selected_playlist.ok? && selected_playlist.result) ||
        (source_type == "track" && selected_track.ok? && selected_track.result) ||
        (source_type == "free" && free_session_name != "")

    step =
      cond do
        content_selected && vote_options_configured && (source_type != "free" || free_vote_mode != nil) -> "4"
        content_selected -> "3"
        source_type -> "2"
        true -> "1"
      end

    socket
    |> assign(:content_selected, content_selected)
    |> assign(:step, step)
  end
end
