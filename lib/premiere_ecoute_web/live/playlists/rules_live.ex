defmodule PremiereEcouteWeb.Playlists.RulesLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography
  alias PremiereEcoute.Playlists

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

    socket
    |> assign(:current_user, User.preload(current_user))
    |> assign(:library_playlists, Discography.LibraryPlaylist.all(where: [user_id: current_user.id]))
    |> assign(:current_rule, Playlists.get_save_tracks_rule(current_user))
    |> assign(:selected_playlist_id, get_current_playlist_id(current_user))
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_playlist", %{"playlist_id" => playlist_id}, socket) do
    current_user = socket.assigns.current_user

    # Find the library playlist by ID
    library_playlist = Enum.find(socket.assigns.library_playlists, &(&1.id == String.to_integer(playlist_id)))

    case library_playlist do
      nil ->
        socket
        |> put_flash(:error, gettext("Playlist not found"))
        |> then(fn socket -> {:noreply, socket} end)

      playlist ->
        case Playlists.set_save_tracks_playlist(current_user, playlist) do
          {:ok, _rule} ->
            socket
            |> assign(:current_rule, Playlists.get_save_tracks_rule(current_user))
            |> assign(:selected_playlist_id, playlist.id)
            |> put_flash(:success, gettext("Save tracks playlist updated to \"%{title}\"", title: playlist.title))
            |> push_event("hide-modal", %{id: "playlist-modal"})
            |> then(fn socket -> {:noreply, socket} end)

          {:error, _changeset} ->
            socket
            |> put_flash(:error, gettext("Failed to update save tracks playlist"))
            |> then(fn socket -> {:noreply, socket} end)
        end
    end
  end

  @impl true
  def handle_event("modal_content_click", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("deactivate_rule", _params, socket) do
    current_user = socket.assigns.current_user

    case Playlists.deactivate_save_tracks_playlist(current_user) do
      {count, _} when count > 0 ->
        socket
        |> assign(:current_rule, nil)
        |> assign(:selected_playlist_id, nil)
        |> put_flash(:success, gettext("Save tracks rule deactivated"))
        |> then(fn socket -> {:noreply, socket} end)

      {0, _} ->
        socket
        |> put_flash(:info, gettext("No active rule to deactivate"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  # AIDEV-NOTE: Helper to get current playlist ID from rule, returns nil if no rule
  defp get_current_playlist_id(user) do
    case Playlists.get_save_tracks_rule(user) do
      nil -> nil
      rule -> rule.library_playlist.id
    end
  end
end
