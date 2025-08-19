defmodule PremiereEcouteWeb.Billboards.DashboardLive do
  @moduledoc """
  Dashboard LiveView for displaying generated billboard results.

  Reuses BillboardLive styles but without the input form.
  Shows cached results or automatically starts generation with progress bar.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Billboards
  alias PremiereEcoute.Billboards.Billboard
  alias PremiereEcoute.Discography.Playlist.Similarity
  alias PremiereEcouteCore.Cache

  @impl true
  def mount(%{"id" => billboard_id}, _session, socket) do
    case Billboards.get_billboard(billboard_id) do
      nil ->
        socket
        |> put_flash(:error, "Billboard not found")
        |> redirect(to: ~p"/billboards")
        |> then(fn socket -> {:ok, socket} end)

      %Billboard{} = billboard ->
        current_user = socket.assigns.current_scope && socket.assigns.current_scope.user

        if current_user && current_user.id == billboard.user_id do
          socket =
            socket
            |> assign(:page_title, "#{billboard.title} - Dashboard")
            |> assign(:billboard, billboard)
            |> assign(
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
              show_modal: false,
              playlist_modal_tab: :tracks
            )

          # AIDEV-NOTE: Check cache first, then auto-generate if needed
          send(self(), :load_dashboard)

          {:ok, socket}
        else
          socket
          |> put_flash(:error, "You don't have permission to access this billboard")
          |> redirect(to: ~p"/billboards")
          |> then(fn socket -> {:ok, socket} end)
        end
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:load_dashboard, socket) do
    billboard = socket.assigns.billboard
    cache_key = "billboard_#{billboard.billboard_id}"

    # AIDEV-NOTE: Try loading from cache first
    case Cache.get(:billboards, cache_key) do
      {:ok, cached_results} when not is_nil(cached_results) ->
        # Direct display from cache
        socket
        |> assign(:loading, false)
        |> assign_results_from_cache(cached_results)
        |> then(fn socket -> {:noreply, socket} end)

      _ ->
        # Not in cache, start generation with progress bar
        urls =
          billboard.submissions
          |> Enum.map(fn
            %{url: url} -> url
            %{"url" => url} -> url
            url when is_binary(url) -> url
          end)
          |> Enum.filter(&is_binary/1)

        if length(urls) > 0 do
          start_generation(socket, urls)
        else
          socket
          |> assign(:loading, false)
          |> assign(:error, "No valid submissions found")
          |> then(fn socket -> {:noreply, socket} end)
        end
    end
  end

  # AIDEV-NOTE: Generation completion handlers
  def handle_info(
        {ref, {:ok, %{playlists: playlists, track: tracks, artist: artists, year: years, year_podium: year_podium}}},
        socket
      ) do
    Process.demonitor(ref, [:flush])

    # Store in cache
    results = %{
      playlists: playlists,
      track: tracks,
      artist: artists,
      year: years,
      year_podium: year_podium
    }

    cache_key = "billboard_#{socket.assigns.billboard.billboard_id}"
    Cache.put(:billboards, cache_key, results)

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

  def handle_info({:progress, text, progress}, socket) do
    {:noreply, assign(socket, progress: progress, progress_text: text)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # AIDEV-NOTE: Event handlers from BillboardLive for modal interactions
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

    selected_year =
      Enum.find(socket.assigns.years, &(&1.rank == rank)) ||
        Enum.find(socket.assigns.year_podium, &(&1.rank == rank))

    {:noreply, assign(socket, selected_year: selected_year, show_modal: true)}
  end

  @impl true
  def handle_event("select_playlist", %{"rank" => rank}, socket) do
    rank = String.to_integer(rank)
    selected_playlist = Enum.find(socket.assigns.playlists, &(&1.rank == rank))

    {:noreply, assign(socket, selected_playlist: selected_playlist, show_modal: true)}
  end

  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, display_mode: String.to_existing_atom(mode))}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     assign(socket,
       selected_track: nil,
       selected_artist: nil,
       selected_year: nil,
       selected_playlist: nil,
       show_modal: false,
       playlist_modal_tab: :tracks
     )}
  end

  @impl true
  def handle_event("switch_playlist_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, playlist_modal_tab: String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  # AIDEV-NOTE: Private helper functions from BillboardLive
  defp start_generation(socket, urls) do
    pid = self()

    task =
      Task.async(fn ->
        Billboards.generate_billboard(
          urls,
          callback: fn text, progress -> send(pid, {:progress, text, progress}) end
        )
      end)

    socket
    |> assign(
      loading: true,
      error: nil,
      tracks: [],
      task: task,
      progress: 0,
      progress_text: "Starting..."
    )
    |> push_event("set_loading", %{loading: true})
    |> then(fn socket -> {:noreply, socket} end)
  end

  defp assign_results_from_cache(socket, cached_results) do
    socket
    |> assign(
      tracks: format_tracks(cached_results.track || []),
      artists: format_artists(cached_results.artist || []),
      years: format_years(cached_results.year || []),
      year_podium: format_year_podium(cached_results.year_podium || []),
      playlists: format_playlists(cached_results.playlists || [])
    )
  end

  defp format_tracks(tracks) when is_list(tracks), do: tracks

  defp format_artists(artists) when is_list(artists), do: artists

  defp format_years(years) when is_list(years) do
    max_count = years |> Enum.map(& &1.count) |> Enum.max(fn -> 1 end)

    years
    |> Enum.map(fn year ->
      max_bars = 25
      bars = max(1, round(year.count / max_count * max_bars))

      year |> Map.put(:bar_count, bars)
    end)
  end

  defp format_year_podium(year_podium) when is_list(year_podium), do: year_podium

  defp format_playlists(playlists) when is_list(playlists) do
    playlists
    |> Enum.with_index(1)
    |> Enum.map(fn {playlist, rank} ->
      playlist
      |> Map.put(:rank, rank)
      |> Map.put(:mean_year, Similarity.calculate_mean_year(playlist.tracks))
      |> Map.put(:top_similar, Similarity.find_most_similar(playlist, playlists))
    end)
  end

  defp rank_icon(1), do: "🥇"
  defp rank_icon(2), do: "🥈"
  defp rank_icon(3), do: "🥉"
  defp rank_icon(_), do: "•"

  defp rank_color(1), do: "text-yellow-400"
  defp rank_color(2), do: "text-gray-300"
  defp rank_color(3), do: "text-orange-400"
  defp rank_color(_), do: "text-cyan-400"

  defp count_color(count) when count >= 30, do: "text-red-400"
  defp count_color(count) when count >= 20, do: "text-orange-400"
  defp count_color(count) when count >= 10, do: "text-yellow-400"
  defp count_color(count) when count >= 5, do: "text-green-400"
  defp count_color(_), do: "text-white"
end
