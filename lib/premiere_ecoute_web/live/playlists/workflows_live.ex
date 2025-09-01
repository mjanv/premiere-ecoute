defmodule PremiereEcouteWeb.Playlists.WorkflowsLive do
  @moduledoc """
  LiveView for managing playlist workflows.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Sessions.Retrospective.History
  alias PremiereEcoute.Apis

  @impl true
  def mount(_params, _session, socket) do
    current_date = DateTime.utc_now()

    socket
    |> assign(:track_count, 50)
    |> assign(:selected_month, format_month(current_date.month))
    |> assign(:selected_year, current_date.year)
    |> assign(:selected_month_number, current_date.month)
    |> assign(:source_type, "my_votes")
    |> assign(:loading_tracks, false)
    |> assign(:tracks, [])
    |> assign(:playlists, load_user_playlists(socket.assigns))
    |> assign(:selected_playlist, nil)
    |> assign(:empty_before, true)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_source", %{"source_type" => source_type}, socket) do
    socket
    |> assign(:source_type, source_type)
    |> assign(:tracks, [])
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("decrease_track_count", _params, %{assigns: %{track_count: count}} = socket) do
    new_count = max(1, count - 10)

    socket
    |> assign(:track_count, new_count)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("increase_track_count", _params, %{assigns: %{track_count: count}} = socket) do
    new_count = min(100, count + 10)

    socket
    |> assign(:track_count, new_count)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("update_track_count", %{"track_count" => track_count}, socket) do
    count =
      case Integer.parse(track_count) do
        {num, _} when num >= 1 and num <= 100 -> num
        _ -> socket.assigns.track_count
      end

    socket
    |> assign(:track_count, count)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("previous_month", _params, socket) do
    %{selected_month_number: month, selected_year: year} = socket.assigns

    {new_month, new_year} =
      if month == 1 do
        {12, year - 1}
      else
        {month - 1, year}
      end

    socket
    |> assign(:selected_month_number, new_month)
    |> assign(:selected_month, format_month(new_month))
    |> assign(:selected_year, new_year)
    |> assign(:tracks, [])
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("next_month", _params, socket) do
    %{selected_month_number: month, selected_year: year} = socket.assigns

    {new_month, new_year} =
      if month == 12 do
        {1, year + 1}
      else
        {month + 1, year}
      end

    socket
    |> assign(:selected_month_number, new_month)
    |> assign(:selected_month, format_month(new_month))
    |> assign(:selected_year, new_year)
    |> assign(:tracks, [])
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("update_target", %{"target_playlist" => playlist_id}, socket) do
    socket
    |> assign(:selected_playlist, playlist_id)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("update_empty_option", %{"empty_before" => value}, socket) do
    empty_before = value == "true"

    socket
    |> assign(:empty_before, empty_before)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("preview_tracks", _params, socket) do
    socket
    |> assign(:loading_tracks, true)
    |> assign(:tracks, [])
    |> then(fn socket ->
      send(self(), :load_preview_tracks)
      {:noreply, socket}
    end)
  end

  @impl true
  def handle_event("create_workflow", _params, socket) do
    %{
      tracks: tracks,
      selected_playlist: playlist_id,
      current_scope: scope
    } = socket.assigns

    IO.inspect(tracks)

    if Enum.empty?(tracks) or is_nil(playlist_id) do
      socket
      |> put_flash(:error, gettext("Please select tracks and a playlist first."))
      |> then(fn socket -> {:noreply, socket} end)
    else
      case export_tracks_to_playlist(scope, playlist_id, tracks) do
        {:ok, _result} ->
          socket
          |> put_flash(:info, gettext("Workflow created successfully! Tracks exported to playlist."))
          |> assign(:tracks, [])
          |> then(fn socket -> {:noreply, socket} end)

        {:error, reason} ->
          socket
          |> put_flash(:error, gettext("Failed to export tracks: %{reason}", reason: inspect(reason)))
          |> then(fn socket -> {:noreply, socket} end)
      end
    end
  end

  @impl true
  def handle_info(:load_preview_tracks, socket) do
    %{
      source_type: source_type,
      track_count: track_count,
      selected_month_number: month,
      selected_year: year,
      current_scope: scope
    } = socket.assigns

    tracks = load_tracks(source_type, track_count, %{month: month, year: year}, scope)

    socket
    |> assign(:loading_tracks, false)
    |> assign(:tracks, tracks)
    |> then(fn socket -> {:noreply, socket} end)
  end

  # Helper functions
  defp format_month(1), do: gettext("January")
  defp format_month(2), do: gettext("February")
  defp format_month(3), do: gettext("March")
  defp format_month(4), do: gettext("April")
  defp format_month(5), do: gettext("May")
  defp format_month(6), do: gettext("June")
  defp format_month(7), do: gettext("July")
  defp format_month(8), do: gettext("August")
  defp format_month(9), do: gettext("September")
  defp format_month(10), do: gettext("October")
  defp format_month(11), do: gettext("November")
  defp format_month(12), do: gettext("December")

  defp load_user_playlists(assigns) do
    if assigns[:current_scope] && assigns.current_scope do
      Discography.LibraryPlaylist.all(where: [user_id: assigns.current_scope.user.id])
      |> Enum.map(fn playlist ->
        %{id: playlist.playlist_id, name: playlist.title}
      end)
    else
      []
    end
  end

  defp load_tracks("my_votes", count, %{month: month, year: year}, scope) do
    if scope && scope.user && scope.user.twitch do
      try do
        scope.user.twitch.user_id
        |> History.get_tracks_by_period(count, :month, %{year: year, month: month})
        |> Enum.map(fn track ->
          %{
            name: track.name || "Unknown Track",
            artist: extract_artist(track) || "Unknown Artist",
            track_id: track.track_id
          }
        end)
      rescue
        error ->
          require Logger
          Logger.error("Error loading tracks: #{inspect(error)}")
          []
      end
    else
      []
    end
  end

  # Workflow export functions
  defp export_tracks_to_playlist(scope, playlist_id, tracks) do
    with {:ok, playlist} <- Apis.spotify().get_playlist(playlist_id),
         {:ok, _} <- remove_all_playlist_tracks(scope, playlist_id, playlist),
         _ <- IO.inspect(tracks, label: ">>"),
         {:ok, result} <- Apis.spotify().add_items_to_playlist(scope, playlist_id, tracks) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, "Failed to export tracks: #{inspect(error)}"}
    end
  end

  defp remove_all_playlist_tracks(_scope, _playlist_id, playlist) when is_nil(playlist.tracks) or playlist.tracks == [] do
    {:ok, nil}
  end

  defp remove_all_playlist_tracks(scope, playlist_id, _playlist) do
    case Apis.spotify().get_playlist(playlist_id) do
      {:ok, current_playlist} ->
        tracks_to_remove = current_playlist.tracks || []

        if length(tracks_to_remove) > 0 do
          Apis.spotify().remove_playlist_items(scope, playlist_id, tracks_to_remove)
        else
          {:ok, nil}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_artist(track) do
    cond do
      Map.has_key?(track, :artist) && track.artist -> track.artist
      Map.has_key?(track, :album) && track.album && Map.has_key?(track.album, :artist) -> track.album.artist
      true -> nil
    end
  end
end
