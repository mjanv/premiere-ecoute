defmodule PremiereEcouteWeb.Billboards.DashboardLive do
  @moduledoc """
  Dashboard LiveView for displaying generated billboard results.

  Reuses BillboardLive styles but without the input form.
  Shows cached results or automatically starts generation with progress bar.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Billboards.Components

  alias PremiereEcoute.Billboards
  alias PremiereEcoute.Billboards.Billboard
  alias PremiereEcoute.Discography.Playlist.Similarity
  alias PremiereEcouteCore.Cache

  @impl true
  def mount(%{"id" => billboard_id}, _session, socket) do
    case Billboards.get_billboard(billboard_id) do
      nil ->
        socket
        |> put_flash(:error, gettext("Billboard not found"))
        |> redirect(to: ~p"/billboards")
        |> then(fn socket -> {:ok, socket} end)

      %Billboard{} = billboard ->
        pid = self()

        socket
        |> stream_configure(:ranking, dom_id: &"ranking-#{&1.rank}")
        |> stream(:ranking, [])
        |> assign(
          billboard: billboard,
          rankings: AsyncResult.loading(),
          podium: [],
          display_mode: :track,
          playlist_modal_tab: :tracks,
          selected: nil,
          progress: %{percentage: 0, message: ""},
          search_query: nil
        )
        |> start_async(:rankings, fn ->
          case Cache.get(:billboards, billboard.billboard_id) do
            {:ok, billboard} when not is_nil(billboard) ->
              billboard

            _ ->
              urls = Enum.map(billboard.submissions, fn %{"url" => url} -> url end)
              callback = fn text, progress -> send(pid, {:progress, text, progress}) end
              results = Billboards.generate_billboard(urls, callback: callback)
              Cache.put(:billboards, billboard.billboard_id, results)
              results
          end
        end)
        |> then(fn socket -> {:ok, socket} end)
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_async(:rankings, {:ok, {:ok, rankings}}, socket) do
    ranking = format(rankings.track, :track)

    socket
    |> stream(:ranking, ranking, reset: true)
    |> assign(
      rankings: AsyncResult.ok(%AsyncResult{}, rankings),
      podium: Enum.take(ranking, 3)
    )
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_async(:rankings, _, socket) do
    socket
    |> assign(:rankings, AsyncResult.failed(socket.assigns.rankings, gettext("No valid submissions found")))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_info({:progress, message, percentage}, socket) do
    {:noreply, assign(socket, progress: %{percentage: percentage, message: message})}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "select",
        %{"rank" => rank, "location" => location},
        %{assigns: %{display_mode: display_mode, rankings: rankings}} = socket
      ) do
    case display_mode do
      :year ->
        case location do
          "list" -> rankings.result.year
          "podium" -> rankings.result.year_podium
        end

      key ->
        Map.get(rankings.result, key)
    end
    |> format(display_mode)
    |> Enum.find(&(&1.rank == String.to_integer(rank)))
    |> then(fn selected -> {:noreply, assign(socket, selected: selected)} end)
  end

  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, %{assigns: %{rankings: rankings}} = socket) do
    mode = String.to_existing_atom(mode)
    ranking = rankings.result |> Map.get(mode) |> format(mode)

    socket
    |> stream(:ranking, ranking, reset: true)
    |> assign(display_mode: mode, podium: Enum.take(ranking, 3))
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event("switch_playlist_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, playlist_modal_tab: String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, selected: nil, playlist_modal_tab: :tracks)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    mode = socket.assigns.display_mode
    rankings = socket.assigns.rankings.result |> Map.get(mode) |> format(mode)

    keys =
      case mode do
        :track -> [:name, :artist]
        :artist -> [:artist]
      end

    ranking = PremiereEcouteCore.Search.filter(rankings, query, keys, 0.7)

    socket
    |> stream(:ranking, ranking, reset: true)
    |> then(fn socket -> {:noreply, socket} end)
  end

  @impl true
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  defp format(tracks, :track) do
    tracks
    |> Enum.map(fn track ->
      track
      |> Map.put(:artist, track.track.artist)
      |> Map.put(:name, track.track.name)
    end)
  end

  defp format(years, :year) do
    max_count = years |> Enum.map(& &1.count) |> Enum.max(fn -> 1 end)

    years
    |> Enum.map(fn year ->
      max_bars = 25
      bars = max(1, round(year.count / max_count * max_bars))

      year |> Map.put(:bar_count, bars)
    end)
  end

  defp format(playlists, :playlists) do
    playlists
    |> Enum.with_index(1)
    |> Enum.map(fn {playlist, rank} ->
      playlist
      |> Map.put(:rank, rank)
      |> Map.put(:mean_year, Similarity.calculate_mean_year(playlist.tracks))
      |> Map.put(:top_similar, Similarity.find_most_similar(playlist, playlists))
    end)
  end

  defp format(list, _), do: list

  defp rank_icon(1, mode) when mode in [:track, :artist], do: "🥇"
  defp rank_icon(2, mode) when mode in [:track, :artist], do: "🥈"
  defp rank_icon(3, mode) when mode in [:track, :artist], do: "🥉"
  defp rank_icon(_, _), do: "•"

  defp rank_color(1, mode) when mode in [:track, :artist], do: "text-yellow-400"
  defp rank_color(2, mode) when mode in [:track, :artist], do: "text-gray-300"
  defp rank_color(3, mode) when mode in [:track, :artist], do: "text-orange-400"
  defp rank_color(_, _), do: "text-cyan-400"

  defp count_color(count) when count >= 30, do: "text-red-400"
  defp count_color(count) when count >= 20, do: "text-orange-400"
  defp count_color(count) when count >= 10, do: "text-yellow-400"
  defp count_color(count) when count >= 5, do: "text-green-400"
  defp count_color(_), do: "text-white"
end
