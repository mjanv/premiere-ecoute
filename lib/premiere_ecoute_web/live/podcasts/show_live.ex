defmodule PremiereEcouteWeb.Podcasts.ShowLive do
  @moduledoc """
  Public podcast show page: show metadata, a link to the RSS feed, and an in-page player per
  episode. The player points at the tracking redirect with `source=web` so website listens are
  counted alongside podcast-app downloads.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Podcasts

  @impl true
  def mount(%{"username" => username, "show_slug" => slug}, _session, socket) do
    socket =
      case Podcasts.get_published_show(username, slug) do
        nil ->
          assign(socket, username: username, show: nil, episodes: [])

        show ->
          assign(socket, username: username, show: show, episodes: Podcasts.feed_episodes(show))
      end

    {:ok, socket}
  end

  @impl true
  def render(%{show: nil} = assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto p-6">
      <h1 class="text-xl font-semibold">{gettext("Podcast not found")}</h1>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto p-6">
      <header class="flex items-center gap-4 mb-6">
        <img
          :if={@show.cover_key}
          src={~p"/podcasts/shows/#{@show.id}/cover"}
          alt={@show.title}
          class="w-24 h-24 rounded object-cover"
        />
        <div>
          <h1 class="text-2xl font-bold">{@show.title}</h1>
          <p class="text-gray-500">{@show.description}</p>
          <a href={~p"/podcasts/#{@username}/#{@show.slug}/feed.xml"} class="text-sm text-indigo-600">
            {gettext("RSS feed")}
          </a>
        </div>
      </header>

      <div :if={@episodes == []} class="text-gray-500">{gettext("No episodes yet.")}</div>

      <ul class="space-y-6">
        <li :for={episode <- @episodes} class="border rounded-lg p-4">
          <div class="font-semibold">{episode.title}</div>
          <p class="text-sm text-gray-500 mb-2">{episode.description}</p>
          <audio
            controls
            preload="none"
            class="w-full"
            src={~p"/podcasts/#{@username}/#{@show.slug}/episodes/#{episode.guid}/audio?#{[source: "web"]}"}
          >
          </audio>
        </li>
      </ul>
    </div>
    """
  end
end
