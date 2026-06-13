defmodule PremiereEcouteWeb.Podcasts.Studio.ShowDashboardLive do
  @moduledoc """
  Streamer studio: a single show's control panel — episode list with publish/unpublish, download
  counts, the RSS feed URL (for directory submission), and show-level publish. Owner only.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Podcasts
  alias PremiereEcoute.Podcasts.Show
  alias PremiereEcoute.Podcasts.Workers.EpisodeIngestionWorker

  @impl true
  def mount(%{"id" => id}, _session, %{assigns: %{current_scope: scope}} = socket) do
    case Podcasts.get_show(id) do
      %Show{user_id: uid} = show when uid == scope.user.id ->
        if connected?(socket), do: PremiereEcoute.PubSub.subscribe(EpisodeIngestionWorker.topic(show.id))
        {:ok, load(socket, show)}

      _ ->
        {:ok, socket |> put_flash(:error, gettext("Show not found")) |> redirect(to: ~p"/studio/podcasts")}
    end
  end

  @impl true
  def handle_info({:episode_updated, _episode_id}, socket) do
    {:noreply, load(socket, socket.assigns.show)}
  end

  defp load(socket, show) do
    episodes = Podcasts.episodes_for_show(show)
    counts = Map.new(episodes, fn e -> {e.id, Podcasts.download_count(e)} end)

    to = DateTime.utc_now()
    from = DateTime.add(to, -29, :day)
    opts = [from: from, to: to, fill_gaps: true]
    feed = Podcasts.show_downloads_over_time(show, :day, Keyword.put(opts, :filters, %{source: "feed"}))
    web = Podcasts.show_downloads_over_time(show, :day, Keyword.put(opts, :filters, %{source: "web"}))

    series =
      Enum.zip(feed, web)
      |> Enum.map(fn {f, w} -> %{period: f.period, feed: f.count, web: w.count, total: f.count + w.count} end)

    assign(socket,
      show: show,
      episodes: episodes,
      counts: counts,
      stats: Podcasts.show_download_stats(show),
      last_30: Podcasts.show_downloads_last(show, 30),
      unique: Podcasts.unique_listeners(show),
      series: series,
      series_max: Enum.reduce(series, 0, &max(&1.total, &2))
    )
  end

  defp bar_height(_count, 0), do: 0
  defp bar_height(count, max), do: round(count / max * 100)

  defp parse_datetime(blank) when blank in ["", nil], do: :now

  defp parse_datetime(string) do
    case NaiveDateTime.from_iso8601(string <> ":00") do
      {:ok, naive} -> {:ok, DateTime.from_naive!(naive, "Etc/UTC")}
      _ -> :now
    end
  end

  @impl true
  def handle_event("publish_show", _params, socket) do
    {:ok, show} = Podcasts.publish_show(socket.assigns.show)
    {:noreply, socket |> put_flash(:info, gettext("Show published")) |> load(show)}
  end

  @impl true
  def handle_event("unpublish_show", _params, socket) do
    {:ok, show} = Podcasts.unpublish_show(socket.assigns.show)
    {:noreply, socket |> put_flash(:info, gettext("Show unpublished")) |> load(show)}
  end

  @impl true
  def handle_event("publish_episode", %{"id" => id} = params, socket) do
    episode = Enum.find(socket.assigns.episodes, &(to_string(&1.id) == id))

    result =
      case parse_datetime(Map.get(params, "at", "")) do
        {:ok, at} -> episode && Podcasts.publish_episode_at(episode, at)
        :now -> episode && Podcasts.publish_episode(episode)
      end

    socket =
      case result do
        {:ok, _} -> socket |> put_flash(:info, gettext("Episode published")) |> load(socket.assigns.show)
        _ -> put_flash(socket, :error, gettext("Action failed"))
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("unpublish_episode", %{"id" => id}, socket) do
    socket = with_episode(socket, id, &Podcasts.unpublish_episode/1, gettext("Episode unpublished"))
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_episode", %{"id" => id}, socket) do
    socket = with_episode(socket, id, &Podcasts.delete_episode/1, gettext("Episode deleted"))
    {:noreply, socket}
  end

  defp with_episode(socket, id, fun, message) do
    episode = Enum.find(socket.assigns.episodes, &(to_string(&1.id) == id))

    case episode && fun.(episode) do
      {:ok, _} -> socket |> put_flash(:info, message) |> load(socket.assigns.show)
      _ -> put_flash(socket, :error, gettext("Action failed"))
    end
  end

  defp feed_url(show), do: url(~p"/podcasts/#{show.user.username}/#{show.slug}/feed.xml")

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto p-6">
        <div class="flex items-center justify-between mb-4">
          <h1 class="text-2xl font-bold">{@show.title}</h1>
          <div class="flex gap-2">
            <.link navigate={~p"/studio/podcasts/#{@show.id}/edit"} class="px-3 py-2 rounded border">{gettext("Edit")}</.link>
            <.link navigate={~p"/studio/podcasts/#{@show.id}/episodes/new"} class="px-3 py-2 rounded bg-indigo-600 text-white">
              {gettext("New episode")}
            </.link>
          </div>
        </div>

        <div class="border rounded-lg p-4 mb-6 bg-gray-50">
          <div class="flex items-center justify-between">
            <div>
              <div class="text-sm text-gray-500">{gettext("RSS feed")}</div>
              <code class="text-sm break-all">{feed_url(@show)}</code>
            </div>
            <button
              :if={!@show.published}
              phx-click="publish_show"
              class="px-3 py-2 rounded bg-green-600 text-white"
            >
              {gettext("Publish show")}
            </button>
            <button
              :if={@show.published}
              phx-click="unpublish_show"
              class="px-3 py-2 rounded border"
            >
              {gettext("Unpublish")}
            </button>
          </div>
          <p class="text-xs text-gray-500 mt-2">
            {gettext("Submit this feed URL once to Apple Podcasts, Spotify, and other apps to distribute your show.")}
          </p>
        </div>

        <div class="grid grid-cols-2 sm:grid-cols-5 gap-3 mb-6">
          <div class="border rounded-lg p-4">
            <div class="text-2xl font-bold">{@stats.total}</div>
            <div class="text-xs text-gray-500">{gettext("Total downloads")}</div>
          </div>
          <div class="border rounded-lg p-4">
            <div class="text-2xl font-bold">{@unique}</div>
            <div class="text-xs text-gray-500">{gettext("Unique listeners")}</div>
          </div>
          <div class="border rounded-lg p-4">
            <div class="text-2xl font-bold">{@last_30}</div>
            <div class="text-xs text-gray-500">{gettext("Last 30 days")}</div>
          </div>
          <div class="border rounded-lg p-4">
            <div class="text-2xl font-bold">{@stats.feed}</div>
            <div class="text-xs text-gray-500">{gettext("Podcast apps")}</div>
          </div>
          <div class="border rounded-lg p-4">
            <div class="text-2xl font-bold">{@stats.web}</div>
            <div class="text-xs text-gray-500">{gettext("Website")}</div>
          </div>
        </div>

        <div class="border rounded-lg p-4 mb-6">
          <div class="flex items-center justify-between mb-3">
            <div class="text-sm font-semibold">{gettext("Downloads (last 30 days)")}</div>
            <div class="flex items-center gap-3 text-xs text-gray-500">
              <span class="flex items-center gap-1">
                <span class="w-2 h-2 rounded-sm bg-indigo-500"></span>{gettext("Podcast apps")}
              </span>
              <span class="flex items-center gap-1">
                <span class="w-2 h-2 rounded-sm bg-emerald-400"></span>{gettext("Website")}
              </span>
            </div>
          </div>
          <div :if={@series_max == 0} class="text-xs text-gray-500">{gettext("No downloads yet.")}</div>
          <div :if={@series_max > 0} class="flex items-end gap-px h-24">
            <div
              :for={point <- @series}
              class="flex-1 flex flex-col justify-end"
              title={"#{Calendar.strftime(point.period, "%d/%m")}: #{point.total}"}
            >
              <div class="bg-emerald-400" style={"height: #{bar_height(point.web, @series_max)}%"}></div>
              <div class="bg-indigo-500 rounded-b" style={"height: #{bar_height(point.feed, @series_max)}%"}></div>
            </div>
          </div>
        </div>

        <h2 class="text-lg font-semibold mb-3">{gettext("Episodes")}</h2>
        <div :if={@episodes == []} class="text-gray-500">{gettext("No episodes yet.")}</div>

        <ul class="space-y-3">
          <li :for={episode <- @episodes} class="border rounded-lg p-4">
            <div class="flex items-center justify-between">
              <div>
                <div class="font-semibold">{episode.title}</div>
                <div class="text-xs text-gray-500">
                  {episode.status}
                  <span :if={episode.published_at}> · {gettext("published")}</span>
                  · {gettext("%{count} downloads", count: @counts[episode.id])}
                </div>
              </div>
              <div class="flex gap-2">
                <form
                  :if={episode.status == :ready and is_nil(episode.published_at)}
                  phx-submit="publish_episode"
                  class="flex items-center gap-1"
                >
                  <input type="hidden" name="id" value={episode.id} />
                  <input
                    type="datetime-local"
                    name="at"
                    title={gettext("Leave empty to publish now")}
                    class="border rounded text-xs px-1 py-0.5"
                  />
                  <button type="submit" class="px-3 py-1 rounded bg-green-600 text-white text-sm">
                    {gettext("Publish")}
                  </button>
                </form>
                <button
                  :if={episode.published_at}
                  phx-click="unpublish_episode"
                  phx-value-id={episode.id}
                  class="px-3 py-1 rounded border text-sm"
                >
                  {gettext("Unpublish")}
                </button>
                <.link
                  navigate={~p"/studio/podcasts/#{@show.id}/episodes/#{episode.id}/edit"}
                  class="px-3 py-1 rounded border text-sm"
                >
                  {gettext("Edit")}
                </.link>
                <button
                  phx-click="delete_episode"
                  phx-value-id={episode.id}
                  data-confirm={gettext("Delete this episode?")}
                  class="px-3 py-1 rounded border border-red-300 text-red-600 text-sm"
                >
                  {gettext("Delete")}
                </button>
              </div>
            </div>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end
end
