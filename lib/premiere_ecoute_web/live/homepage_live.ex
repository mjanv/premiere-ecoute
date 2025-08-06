defmodule PremiereEcouteWeb.HomepageLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.SpotifyApi

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:current_user, User.preload(current_user))
      |> assign(:show_playlist_modal, false)
      |> assign(:playlists_loading, false)
      |> assign(:playlists, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  # AIDEV-NOTE: Show playlist modal and fetch playlists from Spotify API
  @impl true
  def handle_event("show_playlist_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_playlist_modal, true)
      |> assign(:playlists_loading, true)
      |> assign(:playlists, [])

    send(self(), :fetch_playlists)
    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_playlist_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_playlist_modal, false)
      |> assign(:playlists_loading, false)
      |> assign(:playlists, [])

    {:noreply, socket}
  end

  # AIDEV-NOTE: Prevent modal from closing when clicking inside content
  @impl true
  def handle_event("modal_content_click", _params, socket) do
    {:noreply, socket}
  end

  # AIDEV-NOTE: Fetch playlists asynchronously to avoid blocking the UI
  @impl true
  def handle_info(:fetch_playlists, socket) do
    case socket.assigns.current_scope do
      scope when not is_nil(scope) ->
        case SpotifyApi.get_library_playlists(scope) do
          {:ok, playlists} ->
            socket =
              socket
              |> assign(:playlists_loading, false)
              |> assign(:playlists, playlists)

            {:noreply, socket}

          {:error, _reason} ->
            socket =
              socket
              |> assign(:playlists_loading, false)
              |> assign(:playlists, [])

            {:noreply, socket}
        end

      _ ->
        socket =
          socket
          |> assign(:playlists_loading, false)
          |> assign(:playlists, [])

        {:noreply, socket}
    end
  end
end
