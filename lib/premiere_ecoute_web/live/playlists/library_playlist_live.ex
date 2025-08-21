defmodule PremiereEcouteWeb.Playlists.LibraryPlaylistLive do
  @moduledoc """
  LiveView for displaying library playlist details.
  
  Shows playlist information, tracks, and management actions.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography
  alias PremiereEcouteWeb.Layouts

  @impl true
  def mount(%{"id" => playlist_id}, _session, socket) do
    current_user = socket.assigns.current_scope && socket.assigns.current_scope.user
    
    if current_user do
      case find_user_playlist(current_user.id, playlist_id) do
        nil ->
          socket
          |> put_flash(:error, gettext("Playlist not found"))
          |> redirect(to: ~p"/home")
          |> then(fn socket -> {:ok, socket} end)
          
        playlist ->
          socket
          |> assign(:page_title, playlist.title)
          |> assign(:playlist, playlist)
          |> assign(:show_delete_modal, false)
          |> assign(:deleting_playlist, false)
          |> assign(:detailed_playlist, nil)
          |> assign(:tracks, [])
          |> assign(:tracks_loading, true)
          |> assign(:tracks_error, nil)
          |> then(fn socket -> 
            # AIDEV-NOTE: Load detailed playlist with tracks asynchronously
            send(self(), {:load_playlist_details, playlist.playlist_id})
            {:ok, socket} 
          end)
      end
    else
      socket
      |> put_flash(:error, gettext("Please log in to view your playlists"))
      |> redirect(to: ~p"/")
      |> then(fn socket -> {:ok, socket} end)
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, true)}
  end

  @impl true
  def handle_event("hide_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
  end

  @impl true
  def handle_event("delete_playlist", _params, %{assigns: assigns} = socket) do
    case Discography.LibraryPlaylist.delete(assigns.playlist) do
      {:ok, _} ->
        socket
        |> put_flash(:info, gettext("Playlist removed from your library"))
        |> redirect(to: ~p"/home")
        |> then(fn socket -> {:noreply, socket} end)
        
      {:error, _} ->
        socket
        |> assign(:show_delete_modal, false)
        |> put_flash(:error, gettext("Failed to remove playlist"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  @impl true
  def handle_info({:load_playlist_details, playlist_id}, socket) do
    case Apis.spotify().get_playlist(playlist_id) do
      {:ok, detailed_playlist} ->
        socket
        |> assign(:detailed_playlist, detailed_playlist)
        |> assign(:tracks, detailed_playlist.tracks || [])
        |> assign(:tracks_loading, false)
        |> assign(:tracks_error, nil)
        |> then(fn socket -> {:noreply, socket} end)
        
      {:error, reason} ->
        socket
        |> assign(:tracks_loading, false)
        |> assign(:tracks_error, gettext("Failed to load playlist tracks: %{reason}", reason: inspect(reason)))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # AIDEV-NOTE: Find playlist belonging to current user
  defp find_user_playlist(user_id, playlist_id) do
    Discography.LibraryPlaylist.all(
      where: [user_id: user_id, playlist_id: playlist_id],
      limit: 1
    )
    |> List.first()
  end

  defp format_date(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> Calendar.strftime("%b %d, %Y")
  end

  defp format_date(_), do: gettext("Unknown")

  # AIDEV-NOTE: Format track duration from milliseconds to MM:SS
  defp format_duration(duration_ms) when is_integer(duration_ms) do
    total_seconds = div(duration_ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end

  defp format_duration(_), do: "-:--"

  # AIDEV-NOTE: Format track added date
  defp format_track_date(%NaiveDateTime{} = naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> Calendar.strftime("%b %d")
  end

  defp format_track_date(date_string) when is_binary(date_string) do
    case NaiveDateTime.from_iso8601(date_string) do
      {:ok, naive_datetime} -> format_track_date(naive_datetime)
      _ -> gettext("Unknown")
    end
  end

  defp format_track_date(_), do: gettext("Unknown")
end