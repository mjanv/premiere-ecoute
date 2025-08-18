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
      display_mode: :track,
      loading: false,
      error: nil,
      progress: 0,
      progress_text: "",
      selected_track: nil,
      selected_artist: nil,
      selected_year: nil,
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
      
        Billboard.generate_billboard(
            playlist_urls,
            callback: fn text, progress -> send(pid, {:progress, text, progress}) end
          ) |> IO.inspect()

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
    # First check year_podium for podium ranks, then fallback to years by display_rank
    selected_year = 
      Enum.find(socket.assigns.year_podium, &(&1.rank == rank)) ||
      Enum.find(socket.assigns.years, &(&1.display_rank == rank))

    {:noreply, assign(socket, selected_year: selected_year, show_modal: true)}
  end

  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, display_mode: String.to_existing_atom(mode))}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, selected_track: nil, selected_artist: nil, selected_year: nil, show_modal: false)}
  end

  @impl true
  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({ref, {:ok, %{track: tracks, artist: artists, year: years, year_podium: year_podium}}}, socket) do
    Process.demonitor(ref, [:flush])
    
    IO.inspect("OKKKKKKKKKKKKKKKKK!")

    socket
    |> assign(
      tracks: format_tracks(tracks),
      artists: format_artists(artists),
      years: format_years(years),
      year_podium: format_year_podium(year_podium),
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

  # AIDEV-NOTE: Format functions moved from backend to LiveView for presentation control
  defp format_tracks(tracks) when is_list(tracks) do
    tracks
    |> Enum.map(fn track ->
      track
      |> Map.put(:rank_text, String.pad_leading("#{rank_icon(track.rank)} #{track.rank}", 6))
      |> Map.put(:rank_icon, rank_icon(track.rank))
      |> Map.put(:count_text, "[#{track.count}x]")
      |> Map.put(:rank_color, rank_color(track.rank))
      |> Map.put(:count_color, count_color(track.count))
      |> Map.put(:artist, track.track.artist)
      |> Map.put(:name, track.track.name)
      |> Map.put(:track_id, track.track.track_id)
      |> Map.put(:provider, track.track.provider)
      |> Map.put(:provider_url, Track.url(track.track))
      |> Map.put(:playlist_sources, format_playlist_sources(track.tracks))
    end)
  end

  defp format_tracks(tracks) do
    # Fallback for non-list data - return empty list
    []
  end

  defp format_artists(artists) when is_list(artists) do
    artists
    |> Enum.map(fn artist ->
      # Format individual tracks with provider URLs
      # Note: artist.tracks contains raw Track structs, not grouped data with count
      track_counts = artist.tracks |> Enum.frequencies_by(& &1.name)
      
      formatted_tracks = artist.tracks
      |> Enum.uniq_by(& &1.name)
      |> Enum.map(fn track ->
        %{
          name: track.name,
          count: Map.get(track_counts, track.name, 1),
          track_id: track.track_id,
          provider: track.provider,
          provider_url: Track.url(track)
        }
      end)
      
      artist
      |> Map.put(:rank_text, String.pad_leading("#{rank_icon(artist.rank)} #{artist.rank}", 6))
      |> Map.put(:rank_icon, rank_icon(artist.rank))
      |> Map.put(:count_text, "[#{artist.count}x]")
      |> Map.put(:rank_color, rank_color(artist.rank))
      |> Map.put(:count_color, count_color(artist.count))
      |> Map.put(:total_count, artist.count)
      |> Map.put(:tracks, formatted_tracks)
    end)
  end

  defp format_artists(artists) do
    # Fallback for non-list data - return empty list
    []
  end

  defp format_years(years) when is_list(years) do
    max_count = years |> Enum.map(& &1.count) |> Enum.max(fn -> 1 end)
    
    years
    |> Enum.map(fn year ->
      # Always use bullet for year list entries
      list_icon = "•"
      rank_text = String.pad_leading("#{list_icon} #{year.rank}", 6)
      
      max_bars = 25
      bars = max(1, round(year.count / max_count * max_bars))
      
      # Format individual tracks with provider URLs
      # Note: year.tracks contains raw Track structs, not grouped data with count
      track_counts = year.tracks |> Enum.frequencies_by(&("#{&1.artist} - #{&1.name}"))
      
      formatted_tracks = year.tracks
      |> Enum.uniq_by(&("#{&1.artist} - #{&1.name}"))
      |> Enum.map(fn track ->
        track_key = "#{track.artist} - #{track.name}"
        %{
          name: track.name,
          artist: track.artist,
          count: Map.get(track_counts, track_key, 1),
          track_id: track.track_id,
          provider: track.provider,
          provider_url: Track.url(track)
        }
      end)
      
      year
      |> Map.put(:display_rank, year.rank)
      |> Map.put(:rank_text, rank_text)
      |> Map.put(:rank_icon, list_icon)
      |> Map.put(:total_count, year.count)
      |> Map.put(:count_text, "[#{String.duplicate("█", bars)} #{year.count}x]")
      |> Map.put(:podium_count_text, "[#{year.count}x]")
      |> Map.put(:rank_color, "text-cyan-400")
      |> Map.put(:count_color, count_color(year.count))
      |> Map.put(:tracks, formatted_tracks)
    end)
  end

  defp format_years(years) do
    # Fallback for non-list data - return empty list
    []
  end

  defp format_year_podium(year_podium) when is_list(year_podium) do
    year_podium
    |> Enum.map(fn year ->
      # Format individual tracks with provider URLs
      # Note: year.tracks contains raw Track structs, not grouped data with count
      track_counts = year.tracks |> Enum.frequencies_by(&("#{&1.artist} - #{&1.name}"))
      
      formatted_tracks = year.tracks
      |> Enum.uniq_by(&("#{&1.artist} - #{&1.name}"))
      |> Enum.map(fn track ->
        track_key = "#{track.artist} - #{track.name}"
        %{
          name: track.name,
          artist: track.artist,
          count: Map.get(track_counts, track_key, 1),
          track_id: track.track_id,
          provider: track.provider,
          provider_url: Track.url(track)
        }
      end)
      
      year |> Map.put(:tracks, formatted_tracks)
    end)
  end

  defp format_year_podium(year_podium) do
    # Fallback for non-list data - return empty list
    []
  end

  defp format_playlist_sources(tracks) do
    tracks
    |> Enum.map(fn track ->
      # Create a minimal playlist struct for URL generation
      playlist = %Playlist{provider: track.provider, playlist_id: track.playlist_id}
      %{
        provider: track.provider,
        playlist_id: track.playlist_id,
        playlist_url: Playlist.url(playlist)
      }
    end)
    |> Enum.uniq()
  end

  defp rank_icon(1), do: "🥇"
  defp rank_icon(2), do: "🥈"
  defp rank_icon(3), do: "🥉"
  defp rank_icon(_), do: "•"

  defp rank_color(1), do: "text-yellow-400"
  defp rank_color(2), do: "text-gray-300"
  defp rank_color(3), do: "text-orange-400"
  defp rank_color(_), do: "text-cyan-400"

  defp count_color(count) when count >= 10, do: "text-red-400"
  defp count_color(count) when count >= 5, do: "text-yellow-400"
  defp count_color(count) when count >= 2, do: "text-green-400"
  defp count_color(_), do: "text-white"
end
