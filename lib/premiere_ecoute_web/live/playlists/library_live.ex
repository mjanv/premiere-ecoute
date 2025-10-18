defmodule PremiereEcouteWeb.Playlists.LibraryLive do
  use PremiereEcouteWeb, :live_view

  require Logger

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Discography
  alias PremiereEcoute.Playlists

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

    socket
    |> assign(:current_user, User.preload(current_user))
    |> assign(:show_playlist_modal, false)
    |> assign(:show_create_playlist_modal, false)
    |> assign(:playlists_loading, false)
    |> assign(:playlists, [])
    |> assign(:current_page, 1)
    |> assign(:loading_more, false)
    |> assign(:has_more_playlists, true)
    |> assign(:selected_playlist, nil)
    |> assign(:library_playlists, Discography.LibraryPlaylist.all(where: [user_id: current_user.id]))
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_playlist_modal", _params, socket) do
    socket
    |> assign(:show_playlist_modal, true)
    |> assign(:playlists_loading, true)
    |> assign(:playlists, [])
    |> assign(:current_page, 1)
    |> assign(:loading_more, false)
    |> assign(:has_more_playlists, true)
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
    |> assign(:current_page, 1)
    |> assign(:loading_more, false)
    |> assign(:has_more_playlists, true)
    |> assign(:selected_playlist, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("modal_content_click", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more_playlists", _params, socket) do
    if socket.assigns.has_more_playlists and not socket.assigns.loading_more do
      send(self(), :fetch_more_playlists)
      {:noreply, assign(socket, :loading_more, true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_playlist", %{"playlist_id" => playlist_id}, socket) do
    socket
    |> assign(:selected_playlist, Enum.find(socket.assigns.playlists, &(&1.playlist_id == playlist_id)))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("show_create_playlist_modal", _params, socket) do
    socket
    |> assign(:show_create_playlist_modal, true)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("hide_create_playlist_modal", _params, socket) do
    socket
    |> assign(:show_create_playlist_modal, false)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("create_playlist", %{"playlist" => playlist_params}, %{assigns: %{current_scope: current_scope}} = socket) do
    playlist = %Discography.LibraryPlaylist{
      title: playlist_params["title"],
      description: playlist_params["description"],
      public: playlist_params["public"] == "true" || playlist_params["public"] == true,
      provider: :spotify
    }

    case Playlists.create_library_playlist(current_scope, playlist) do
      {:ok, _playlist} ->
        socket
        |> assign(:show_create_playlist_modal, false)
        |> assign(:library_playlists, Discography.LibraryPlaylist.all(where: [user_id: current_scope.user.id]))
        |> put_flash(:success, gettext("Playlist created successfully!"))

      {:error, reason} ->
        socket
        |> put_flash(:error, gettext("Failed to create playlist: %{reason}", reason: inspect(reason)))
    end
    |> then(fn socket -> {:noreply, socket} end)
  end

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
              |> assign(:show_playlist_modal, false)
              |> assign(:library_playlists, Discography.LibraryPlaylist.all(where: [user_id: current_scope.user.id]))
              |> put_flash(:success, gettext("Playlist added to your library!"))

            {:error, reason} ->
              Logger.error("#{inspect(reason)}")

              socket
              |> put_flash(:error, gettext("Failed to add playlist to your library"))
          end
          |> then(fn socket -> {:noreply, socket} end)
        end
    end
  end

  def handle_info(:fetch_playlists, %{assigns: %{current_scope: scope}} = socket) do
    case SpotifyApi.get_library_playlists(scope, 1) do
      {:ok, playlists} ->
        socket
        |> assign(:playlists_loading, false)
        |> assign(:playlists, playlists)
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
end
