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

    assign(socket,
      show: show,
      episodes: episodes,
      counts: counts,
      stats: Podcasts.show_download_stats(show),
      last_30: Podcasts.show_downloads_last(show, 30),
      unique: Podcasts.unique_listeners(show)
    )
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
  def handle_event("publish_episode", %{"id" => id}, socket) do
    socket = with_episode(socket, id, &Podcasts.publish_episode/1, gettext("Episode published"))
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

  defp public_url(show), do: ~p"/podcasts/#{show.user.username}/#{show.slug}"

  defp episode_url(show, episode),
    do: ~p"/podcasts/#{show.user.username}/#{show.slug}/episodes/#{episode.guid}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_page="podcasts">
      <div class="synthwave-bg min-h-screen text-white">
        <div class="max-w-3xl mx-auto px-6 py-12">
          <div class="flex items-center justify-between mb-6 gap-3">
            <div class="flex items-center gap-3 min-w-0">
              <img
                :if={@show.cover_key}
                src={~p"/podcasts/shows/#{@show.id}/cover"}
                alt={@show.title}
                class="w-12 h-12 rounded-lg object-cover flex-shrink-0"
              />
              <h1 class="text-2xl font-bold text-white truncate">{@show.title}</h1>
            </div>
            <div class="flex gap-2 flex-shrink-0">
              <.link
                :if={@show.published}
                navigate={public_url(@show)}
                class="px-3 py-2 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 text-white text-sm transition-colors"
              >
                {gettext("View public page")}
              </.link>
              <.link
                navigate={~p"/studio/podcasts/#{@show.id}/edit"}
                class="px-3 py-2 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 text-white text-sm transition-colors"
              >
                {gettext("Edit")}
              </.link>
              <.link
                navigate={~p"/studio/podcasts/#{@show.id}/episodes/new"}
                class="px-3 py-2 rounded-lg bg-purple-600 hover:bg-purple-700 text-white text-sm font-medium transition-colors"
              >
                {gettext("New episode")}
              </.link>
            </div>
          </div>

          <div class="rounded-xl bg-white/5 border border-white/10 p-4 mb-6">
            <div class="flex items-center justify-between gap-4">
              <div class="min-w-0">
                <div class="text-sm text-gray-400">{gettext("RSS feed")}</div>
                <code class="text-sm text-purple-300 break-all">{feed_url(@show)}</code>
              </div>
              <button
                :if={!@show.published}
                phx-click="publish_show"
                class="px-3 py-2 rounded-lg bg-green-600 hover:bg-green-700 text-white text-sm font-medium transition-colors flex-shrink-0"
              >
                {gettext("Publish show")}
              </button>
              <button
                :if={@show.published}
                phx-click="unpublish_show"
                class="px-3 py-2 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 text-white text-sm transition-colors flex-shrink-0"
              >
                {gettext("Unpublish")}
              </button>
            </div>
            <p class="text-xs text-gray-400 mt-2">
              {gettext("Submit this feed URL once to Apple Podcasts, Spotify, and other apps to distribute your show.")}
            </p>
          </div>

          <div class="grid grid-cols-2 sm:grid-cols-5 gap-3 mb-6">
            <div class="rounded-xl bg-white/5 border border-white/10 p-4">
              <div class="text-2xl font-bold text-white">{@stats.total}</div>
              <div class="text-xs text-gray-400">{gettext("Total downloads")}</div>
            </div>
            <div class="rounded-xl bg-white/5 border border-white/10 p-4">
              <div class="text-2xl font-bold text-white">{@unique}</div>
              <div class="text-xs text-gray-400">{gettext("Unique listeners")}</div>
            </div>
            <div class="rounded-xl bg-white/5 border border-white/10 p-4">
              <div class="text-2xl font-bold text-white">{@last_30}</div>
              <div class="text-xs text-gray-400">{gettext("Last 30 days")}</div>
            </div>
            <div class="rounded-xl bg-white/5 border border-white/10 p-4">
              <div class="text-2xl font-bold text-white">{@stats.feed}</div>
              <div class="text-xs text-gray-400">{gettext("Podcast apps")}</div>
            </div>
            <div class="rounded-xl bg-white/5 border border-white/10 p-4">
              <div class="text-2xl font-bold text-white">{@stats.web}</div>
              <div class="text-xs text-gray-400">{gettext("Website")}</div>
            </div>
          </div>

          <%!-- 30-day downloads chart hidden until the source-split series is fixed. --%>

          <h2 class="text-lg font-semibold text-white mb-3">{gettext("Episodes")}</h2>
          <div :if={@episodes == []} class="text-gray-400">{gettext("No episodes yet.")}</div>

          <ul class="space-y-3">
            <li :for={episode <- @episodes} class="rounded-xl bg-white/5 border border-white/10 p-4">
              <div class="flex items-center justify-between gap-3">
                <div class="min-w-0">
                  <div class="font-semibold text-white truncate">{episode.title}</div>
                  <div class="text-xs text-gray-400">
                    <span>{episode.status}</span>
                    <span :if={episode.published_at}>· {gettext("published")}</span>
                    <span>· {gettext("%{count} downloads", count: @counts[episode.id])}</span>
                    <span :if={episode.published_at}>
                      ·
                      <.link
                        navigate={episode_url(@show, episode)}
                        class="text-purple-300 hover:text-purple-200 underline transition-colors"
                      >
                        {gettext("listen")}
                      </.link>
                    </span>
                  </div>
                </div>
                <div class="flex gap-2 flex-shrink-0">
                  <button
                    :if={episode.status == :ready and is_nil(episode.published_at)}
                    phx-click="publish_episode"
                    phx-value-id={episode.id}
                    class="px-3 py-1 rounded-lg bg-green-600 hover:bg-green-700 text-white text-sm transition-colors"
                  >
                    {gettext("Publish")}
                  </button>
                  <button
                    :if={episode.published_at}
                    phx-click="unpublish_episode"
                    phx-value-id={episode.id}
                    class="px-3 py-1 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 text-white text-sm transition-colors"
                  >
                    {gettext("Unpublish")}
                  </button>
                  <.link
                    navigate={~p"/studio/podcasts/#{@show.id}/episodes/#{episode.id}/edit"}
                    class="px-3 py-1 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 text-white text-sm transition-colors"
                  >
                    {gettext("Edit")}
                  </.link>
                  <button
                    phx-click="delete_episode"
                    phx-value-id={episode.id}
                    data-confirm={gettext("Delete this episode?")}
                    class="px-3 py-1 rounded-lg bg-red-600/20 hover:bg-red-600/40 text-red-400 hover:text-red-300 text-sm transition-colors"
                  >
                    {gettext("Delete")}
                  </button>
                </div>
              </div>
            </li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
