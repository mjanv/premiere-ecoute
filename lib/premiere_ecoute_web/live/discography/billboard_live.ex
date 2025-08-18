defmodule PremiereEcouteWeb.Discography.BillboardLive do
  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography.Billboard
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(
      playlist_form: to_form(%{"playlist_input" => nil}),
      tracks: [],
      artists: [],
      years: [],
      year_podium: [],
      playlists: [],
      display_mode: :track,
      loading: false,
      error: nil,
      progress: 0,
      progress_text: "",
      selected_track: nil,
      selected_artist: nil,
      selected_year: nil,
      selected_playlist: nil,
      show_modal: false
    )
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("generate_billboard", %{"playlist_input" => playlist_input}, socket) do
    playlist_urls = String.split(playlist_input, ["\n", "\r\n", "\r"], trim: true)

    if length(playlist_urls) > 0 do
      pid = self()

      task =
        Task.async(fn ->
          Billboard.generate_billboard(
            playlist_urls,
            callback: fn text, progress -> send(pid, {:progress, text, progress}) end
          )
        end)

      socket
      |> assign(
        playlist_form: to_form(%{"playlist_input" => playlist_input}),
        loading: true,
        error: nil,
        tracks: [],
        task: task,
        progress: 0,
        progress_text: "Starting..."
      )
      |> push_event("set_loading", %{loading: true})
      |> then(fn socket -> {:noreply, socket} end)
    else
      {:noreply, assign(socket, error: "Please enter at least one playlist URL")}
    end
  end

  @impl true
  def handle_event("generate_billboard", _params, socket) do
    {:noreply, assign(socket, error: "Please enter at least one playlist URL")}
  end

  @impl true
  def handle_event("clear_results", _params, socket) do
    socket
    |> assign(
      tracks: [],
      artists: [],
      years: [],
      year_podium: [],
      playlists: [],
      loading: false,
      error: nil,
      task: nil,
      progress: 0,
      progress_text: ""
    )
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("playlist_loaded", %{"value" => value}, socket) do
    {:noreply, assign(socket, playlist_form: to_form(%{"playlist_input" => value}))}
  end

  @impl true
  def handle_event("update_playlist_input", %{"playlist_input" => playlist_input}, socket) do
    {:noreply, assign(socket, playlist_form: to_form(%{"playlist_input" => playlist_input}))}
  end

  @impl true
  def handle_event("select_track", %{"rank" => rank}, socket) do
    rank = String.to_integer(rank)
    selected_track = Enum.find(socket.assigns.tracks, &(&1.rank == rank))

    {:noreply, assign(socket, selected_track: selected_track, show_modal: true)}
  end

  @impl true
  def handle_event("select_artist", %{"rank" => rank}, socket) do
    rank = String.to_integer(rank)
    selected_artist = Enum.find(socket.assigns.artists, &(&1.rank == rank))

    {:noreply, assign(socket, selected_artist: selected_artist, show_modal: true)}
  end

  @impl true
  def handle_event("select_year", %{"rank" => rank}, socket) do
    rank = String.to_integer(rank)
    # First check year_podium for podium ranks, then fallback to years by rank
    selected_year =
      Enum.find(socket.assigns.year_podium, &(&1.rank == rank)) ||
        Enum.find(socket.assigns.years, &(&1.rank == rank))

    {:noreply, assign(socket, selected_year: selected_year, show_modal: true)}
  end

  @impl true
  def handle_event("select_playlist", %{"playlist_id" => playlist_id}, socket) do
    selected_playlist = Enum.find(socket.assigns.playlists, &(&1.playlist_id == playlist_id))

    {:noreply, assign(socket, selected_playlist: selected_playlist, show_modal: true)}
  end

  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, display_mode: String.to_existing_atom(mode))}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     assign(socket, selected_track: nil, selected_artist: nil, selected_year: nil, selected_playlist: nil, show_modal: false)}
  end

  @impl true
  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {ref, {:ok, %{playlists: playlists, track: tracks, artist: artists, year: years, year_podium: year_podium}}},
        socket
      ) do
    Process.demonitor(ref, [:flush])

    socket
    |> assign(
      tracks: format_tracks(tracks),
      artists: format_artists(artists),
      years: format_years(years),
      year_podium: format_year_podium(year_podium),
      playlists: format_playlists(playlists),
      loading: false,
      error: nil,
      task: nil,
      progress: 0,
      progress_text: ""
    )
    |> push_event("set_loading", %{loading: false})
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({ref, {:error, reason}}, socket) do
    Process.demonitor(ref, [:flush])

    socket
    |> assign(
      loading: false,
      error: "Failed to generate billboard: #{reason}",
      task: nil,
      progress: 0,
      progress_text: ""
    )
    |> push_event("set_loading", %{loading: false})
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    socket
    |> assign(
      loading: false,
      error: "Failed to generate billboard: request was interrupted",
      task: nil,
      progress: 0,
      progress_text: ""
    )
    |> push_event("set_loading", %{loading: false})
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:progress, text, progress}, socket) do
    {:noreply, assign(socket, progress: progress, progress_text: text)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp format_tracks(tracks) when is_list(tracks) do
    tracks
  end

  defp format_artists(artists) when is_list(artists) do
    artists
  end

  defp format_years(years) when is_list(years) do
    max_count = years |> Enum.map(& &1.count) |> Enum.max(fn -> 1 end)

    years
    |> Enum.map(fn year ->
      max_bars = 25
      bars = max(1, round(year.count / max_count * max_bars))

      year |> Map.put(:bar_count, bars)
    end)
  end

  defp format_year_podium(year_podium) when is_list(year_podium) do
    year_podium
  end

  defp format_playlists(playlists) when is_list(playlists) do
    playlists
    |> Enum.with_index(1)
    |> Enum.map(fn {playlist, rank} -> 
      mean_year = calculate_mean_year(playlist.tracks)
      playlist
      |> Map.put(:rank, rank)
      |> Map.put(:mean_year, mean_year)
    end)
  end

  defp calculate_mean_year(tracks) when is_list(tracks) do
    if length(tracks) > 0 do
      total_years = tracks |> Enum.map(&(&1.release_date.year)) |> Enum.sum()
      round(total_years / length(tracks))
    else
      nil
    end
  end

  defp rank_icon(1), do: "🥇"
  defp rank_icon(2), do: "🥈"
  defp rank_icon(3), do: "🥉"
  defp rank_icon(_), do: "•"

  defp rank_color(1), do: "text-yellow-400"
  defp rank_color(2), do: "text-gray-300"
  defp rank_color(3), do: "text-orange-400"
  defp rank_color(_), do: "text-cyan-400"

  defp count_color(count) when count >= 20, do: "text-red-400"
  defp count_color(count) when count >= 10, do: "text-yellow-400"
  defp count_color(count) when count >= 5, do: "text-green-400"
  defp count_color(_), do: "text-white"
end
