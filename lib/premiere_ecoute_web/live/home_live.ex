defmodule PremiereEcouteWeb.HomeLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Billboards
  alias PremiereEcoute.Discography
  alias PremiereEcoute.Sessions.ListeningSession

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

    socket
    |> assign(:current_user, User.preload(current_user))
    |> assign(:show_playlist_modal, false)
    |> assign(:playlists_loading, false)
    |> assign(:playlists, [])
    # AIDEV-NOTE: Track pagination state for playlists
    |> assign(:current_page, 1)
    |> assign(:loading_more, false)
    |> assign(:has_more_playlists, true)
    # AIDEV-NOTE: Track selected playlist for registration
    |> assign(:selected_playlist, nil)
    # AIDEV-NOTE: Track playlist detail modal
    |> assign(:show_playlist_detail_modal, false)
    |> assign(:selected_library_playlist, nil)
    # AIDEV-NOTE: Load user's library playlists, session status, and recent billboards
    |> load_library_playlists()
    |> assign(:current_session, ListeningSession.current_session(current_user))
    |> load_recent_billboards()
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  # AIDEV-NOTE: Show playlist modal and fetch playlists from Spotify API
  @impl true
  def handle_event("show_playlist_modal", _params, socket) do
    socket
    |> assign(:show_playlist_modal, true)
    |> assign(:playlists_loading, true)
    |> assign(:playlists, [])
    # Reset pagination state
    |> assign(:current_page, 1)
    |> assign(:loading_more, false)
    |> assign(:has_more_playlists, true)
    # Reset selection state
    |> assign(:selected_playlist, nil)
    |> tap(fn _ -> send(self(), :fetch_playlists) end)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("hide_playlist_modal", _params, socket) do
    socket
    |> assign(:show_playlist_modal, false)
    |> assign(:playlists_loading, false)
    |> assign(:playlists, [])
    # Reset pagination state
    |> assign(:current_page, 1)
    |> assign(:loading_more, false)
    |> assign(:has_more_playlists, true)
    # Reset selection state
    |> assign(:selected_playlist, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  # AIDEV-NOTE: Prevent modal from closing when clicking inside content
  @impl true
  def handle_event("modal_content_click", _params, socket) do
    {:noreply, socket}
  end

  # AIDEV-NOTE: Load more playlists for pagination
  @impl true
  def handle_event("load_more_playlists", _params, socket) do
    if socket.assigns.has_more_playlists and not socket.assigns.loading_more do
      send(self(), :fetch_more_playlists)
      {:noreply, assign(socket, :loading_more, true)}
    else
      {:noreply, socket}
    end
  end

  # AIDEV-NOTE: Select a playlist for potential registration
  @impl true
  def handle_event("select_playlist", %{"playlist_id" => playlist_id}, socket) do
    socket
    |> assign(:selected_playlist, Enum.find(socket.assigns.playlists, &(&1.playlist_id == playlist_id)))
    |> then(fn socket -> {:noreply, socket} end)
  end

  # AIDEV-NOTE: Show playlist detail modal
  @impl true
  def handle_event("show_playlist_detail", %{"playlist_id" => playlist_id}, socket) do
    selected_playlist = Enum.find(socket.assigns.library_playlists || [], &(&1.playlist_id == playlist_id))

    socket
    |> assign(:show_playlist_detail_modal, true)
    |> assign(:selected_library_playlist, selected_playlist)
    |> assign(:deleting_playlist, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  # AIDEV-NOTE: Hide playlist detail modal
  @impl true
  def handle_event("hide_playlist_detail_modal", _params, socket) do
    socket
    |> assign(:show_playlist_detail_modal, false)
    |> assign(:selected_library_playlist, nil)
    |> assign(:deleting_playlist, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  # AIDEV-NOTE: Delete playlist from library
  @impl true
  def handle_event("delete_playlist", _params, %{assigns: assigns} = socket) do
    case assigns.selected_library_playlist do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("No playlist selected"))}

      playlist ->
        case Discography.LibraryPlaylist.delete(playlist) do
          {:ok, _} ->
            socket
            |> assign(:show_playlist_detail_modal, false)
            |> assign(:selected_library_playlist, nil)
            |> load_library_playlists()
            |> put_flash(:success, gettext("Playlist removed from your library"))

          {:error, _} ->
            socket
            |> put_flash(:error, gettext("Failed to remove playlist"))
        end
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  # AIDEV-NOTE: Register selected playlist to user's library
  @impl true
  def handle_event("register_playlist", _params, %{assigns: %{current_scope: current_scope}} = socket) do
    case socket.assigns.selected_playlist do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("No playlist selected"))}

      playlist ->
        if Discography.LibraryPlaylist.exists?(current_scope.user, playlist) do
          {:noreply, put_flash(socket, :info, gettext("Playlist is already in your library"))}
        else
          attrs = %{
            provider: playlist.provider,
            playlist_id: playlist.playlist_id,
            title: playlist.title,
            description: playlist.description,
            url: playlist.url,
            cover_url: playlist.cover_url,
            public: playlist.public,
            track_count: 0,
            metadata: playlist.metadata || %{}
          }

          case Discography.LibraryPlaylist.create(current_scope.user, attrs) do
            {:ok, _} ->
              socket
              |> assign(:selected_playlist, nil)
              |> load_library_playlists()
              |> put_flash(:success, gettext("Playlist added to your library!"))

            {:error, _} ->
              socket
              |> put_flash(:error, gettext("Failed to add playlist to your library"))
          end
          |> then(fn socket -> {:noreply, socket} end)
        end
    end
  end

  # AIDEV-NOTE: Fetch playlists asynchronously to avoid blocking the UI
  @impl true
  def handle_info(:fetch_playlists, %{assigns: %{current_scope: scope}} = socket) do
    case SpotifyApi.get_library_playlists(scope, 1) do
      {:ok, playlists} ->
        socket
        |> assign(:playlists_loading, false)
        |> assign(:playlists, playlists)
        # AIDEV-NOTE: If we got less than 1 playlist, there are no more pages
        |> assign(:has_more_playlists, length(playlists) >= 1)
        |> assign(:current_page, 1)
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _reason} ->
        socket
        |> assign(:playlists_loading, false)
        |> assign(:playlists, [])
        |> assign(:has_more_playlists, false)
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  # AIDEV-NOTE: Fetch more playlists for pagination
  @impl true
  def handle_info(:fetch_more_playlists, %{assigns: %{current_scope: scope, current_page: page}} = socket) do
    next_page = page + 1

    case SpotifyApi.get_library_playlists(scope, next_page) do
      {:ok, playlists} ->
        socket
        |> assign(:loading_more, false)
        |> assign(:playlists, socket.assigns.playlists ++ playlists)
        |> assign(:current_page, next_page)
        |> assign(:has_more_playlists, length(playlists) >= 1)
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _reason} ->
        socket
        |> assign(:loading_more, false)
        |> assign(:has_more_playlists, false)
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  defp load_library_playlists(%{assigns: assigns} = socket) do
    if assigns.current_scope do
      library_playlists = Discography.LibraryPlaylist.all(where: [user_id: assigns.current_scope.user.id])
      assign(socket, :library_playlists, library_playlists)
    else
      assign(socket, :library_playlists, [])
    end
  end

  # AIDEV-NOTE: Load user's latest billboard for recap
  defp load_recent_billboards(%{assigns: assigns} = socket) do
    if assigns.current_scope do
      latest_billboard = 
        Billboards.all(
          where: [user_id: assigns.current_scope.user.id],
          order_by: [desc: :inserted_at],
          limit: 1
        )
        |> List.first()
      
      assign(socket, :latest_billboard, latest_billboard)
    else
      assign(socket, :latest_billboard, nil)
    end
  end

  # AIDEV-NOTE: Format date for display
  defp simple_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  defp simple_date(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> simple_date()
  end

  defp simple_date(_), do: gettext("Unknown")
end
