defmodule PremiereEcouteWeb.Discography.PlaylistLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.LibraryPlaylist

  @impl true
  def mount(%{"id" => playlist_id}, _session, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user
    library_playlist = LibraryPlaylist.get_by(user_id: current_user.id, playlist_id: playlist_id)

    socket =
      socket
      |> assign(:playlist_id, playlist_id)
      |> assign(:library_playlist, library_playlist)
      |> assign(:playlist, nil)
      |> assign(:loading, true)
      |> assign(:error, nil)
      |> assign(:search_query, "")
      |> assign(:date_filter, "all")
      |> assign(:filtered_tracks, [])
      |> assign(:selected_tracks, MapSet.new())
      |> assign(:select_all, false)
      |> assign(:deleting_tracks, false)

    if library_playlist do
      send(self(), :fetch_playlist_data)
      {:ok, socket}
    else
      {:ok, assign(socket, :error, gettext("Playlist not found in your library"))}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_playlist", _params, socket) do
    send(self(), :fetch_playlist_data)
    {:noreply, assign(socket, :loading, true)}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    socket
    |> assign(:search_query, query)
    |> apply_filters()
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("filter_by_date", %{"date_filter" => date_filter}, socket) do
    socket
    |> assign(:date_filter, date_filter)
    |> apply_filters()
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    socket
    |> assign(:search_query, "")
    |> assign(:date_filter, "all")
    |> apply_filters()
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("toggle_track_selection", %{"track_id" => track_id}, socket) do
    selected_tracks = socket.assigns.selected_tracks

    new_selected_tracks =
      if MapSet.member?(selected_tracks, track_id) do
        MapSet.delete(selected_tracks, track_id)
      else
        MapSet.put(selected_tracks, track_id)
      end

    # Update select all state based on current selection
    current_track_ids = get_current_track_ids(socket)
    select_all = MapSet.equal?(new_selected_tracks, MapSet.new(current_track_ids))

    socket
    |> assign(:selected_tracks, new_selected_tracks)
    |> assign(:select_all, select_all)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("toggle_select_all", _params, socket) do
    current_track_ids = get_current_track_ids(socket)

    {new_selected_tracks, new_select_all} =
      if socket.assigns.select_all do
        # Deselect all current tracks
        {MapSet.difference(socket.assigns.selected_tracks, MapSet.new(current_track_ids)), false}
      else
        # Select all current tracks
        {MapSet.union(socket.assigns.selected_tracks, MapSet.new(current_track_ids)), true}
      end

    socket
    |> assign(:selected_tracks, new_selected_tracks)
    |> assign(:select_all, new_select_all)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("delete_selected_tracks", _params, socket) do
    selected_tracks = socket.assigns.selected_tracks

    if MapSet.size(selected_tracks) == 0 do
      {:noreply, put_flash(socket, :error, gettext("No tracks selected"))}
    else
      socket
      |> assign(:deleting_tracks, true)
      |> then(fn socket ->
        send(self(), {:delete_tracks, MapSet.to_list(selected_tracks)})
        {:noreply, socket}
      end)
    end
  end

  @impl true
  def handle_event("clear_selection", _params, socket) do
    socket
    |> assign(:selected_tracks, MapSet.new())
    |> assign(:select_all, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("remove_from_library", _params, socket) do
    case socket.assigns.library_playlist do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Playlist not found"))}

      library_playlist ->
        case LibraryPlaylist.delete(library_playlist) do
          {:ok, _} ->
            socket
            |> put_flash(:success, gettext("Playlist removed from your library"))
            |> push_navigate(to: ~p"/discography/library")

          {:error, _} ->
            socket
            |> put_flash(:error, gettext("Failed to remove playlist"))
        end
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  @impl true
  def handle_event("open_in_provider", _params, socket) do
    case socket.assigns.library_playlist do
      nil ->
        {:noreply, socket}

      library_playlist ->
        url =
          case library_playlist.provider do
            :spotify -> "https://open.spotify.com/playlist/#{library_playlist.playlist_id}"
            :deezer -> "https://www.deezer.com/playlist/#{library_playlist.playlist_id}"
          end

        {:noreply, redirect(socket, external: url)}
    end
  end

  @impl true
  def handle_info(:fetch_playlist_data, %{assigns: %{library_playlist: library_playlist}} = socket) do
    case Apis.provider(library_playlist.provider).get_playlist(library_playlist.playlist_id) do
      {:ok, playlist} ->
        socket
        |> assign(:playlist, playlist)
        |> assign(:loading, false)
        |> assign(:error, nil)
        |> apply_filters()

      {:error, _} ->
        socket
        |> assign(:loading, false)
        |> assign(:error, gettext("Failed to load playlist data"))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:delete_tracks, track_ids}, %{assigns: assigns} = socket) do
    case delete_tracks_from_playlist(assigns.library_playlist, assigns.current_scope, track_ids) do
      {:ok, _} ->
        socket
        |> assign(:deleting_tracks, false)
        |> assign(:selected_tracks, MapSet.new())
        |> assign(:select_all, false)
        |> put_flash(:success, gettext("%{count} tracks removed from playlist", count: length(track_ids)))
        |> then(fn socket ->
          # Refresh playlist data
          send(self(), :fetch_playlist_data)
          socket
        end)

      {:error, _} ->
        socket
        |> assign(:deleting_tracks, false)
        |> put_flash(:error, gettext("Failed to delete tracks from playlist"))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

  defp total_duration(tracks) do
    tracks
    |> Enum.map(&(&1.duration_ms || 0))
    |> Enum.sum()
    |> PremiereEcouteCore.Duration.duration()
  end

  # AIDEV-NOTE: Apply search and date filters to playlist tracks
  defp apply_filters(%{assigns: assigns} = socket) do
    tracks = (assigns.playlist && assigns.playlist.tracks) || []

    filtered_tracks =
      tracks
      |> PremiereEcouteCore.Search.filter(assigns.search_query, [:name, :artist, :user_id])
      |> filter_by_date(assigns.date_filter)

    # Clear selection when filters change to avoid confusion
    socket
    |> assign(:filtered_tracks, filtered_tracks)
    |> assign(:selected_tracks, MapSet.new())
    |> assign(:select_all, false)
  end

  defp filter_by_date(tracks, "all"), do: tracks

  defp filter_by_date(tracks, date_filter) do
    cutoff_date =
      case date_filter do
        "week" -> Date.add(Date.utc_today(), -7)
        _ -> nil
      end

    if cutoff_date do
      Enum.filter(tracks, fn track ->
        case track.release_date do
          %Date{} = release_date -> Date.compare(release_date, cutoff_date) == :lt
          _ -> false
        end
      end)
    else
      tracks
    end
  end

  # AIDEV-NOTE: Get track IDs for current displayed tracks (filtered or all)
  defp get_current_track_ids(socket) do
    tracks =
      if socket.assigns.search_query != "" || socket.assigns.date_filter != "all" do
        socket.assigns.filtered_tracks || []
      else
        (socket.assigns.playlist && socket.assigns.playlist.tracks) || []
      end

    Enum.map(tracks, & &1.track_id)
  end

  defp delete_tracks_from_playlist(%{provider: :spotify, playlist_id: playlist_id}, scope, track_ids) do
    Apis.spotify().remove_playlist_items(scope, playlist_id, Enum.map(track_ids, &%{track_id: &1}))
  end

  defp delete_tracks_from_playlist(_, _, _), do: {:error, :unsupported_provider}
end
