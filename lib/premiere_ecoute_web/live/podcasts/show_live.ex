defmodule PremiereEcouteWeb.Podcasts.ShowLive do
  @moduledoc """
  Public podcast show page: show metadata, a link to the RSS feed, and an in-page player per
  episode. The player points at the tracking redirect with `source=web` so website listens are
  counted alongside podcast-app downloads.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Podcasts.Components

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
    <Layouts.app flash={@flash} current_scope={@current_scope} current_page="podcasts">
      <div class="synthwave-bg min-h-screen text-white">
        <div class="max-w-3xl mx-auto px-6 py-12">
          <h1 class="text-xl font-semibold text-white">{gettext("Podcast not found")}</h1>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_page="podcasts">
      <div class="synthwave-bg min-h-screen text-white">
        <div class="max-w-3xl mx-auto px-6 py-12">
          <header class="flex items-start gap-4 mb-8">
            <img
              :if={@show.cover_key}
              src={~p"/podcasts/shows/#{@show.id}/cover"}
              alt={@show.title}
              class="w-24 h-24 rounded-xl object-cover flex-shrink-0"
            />
            <div class="min-w-0">
              <h1 class="text-2xl font-bold text-white">{@show.title}</h1>
              <p class="text-gray-400">{@show.description}</p>
              <div class="mt-3">
                <div class="text-xs text-gray-400 mb-1">{gettext("Subscribe in your podcast app")}</div>
                <div class="flex items-center gap-2">
                  <input
                    type="text"
                    readonly
                    value={url(~p"/podcasts/#{@username}/#{@show.slug}/feed.xml")}
                    class="rounded-lg px-3 py-1.5 text-xs flex-1 max-w-md bg-white/5 border border-white/10 text-gray-300"
                  />
                  <button
                    type="button"
                    onclick={"navigator.clipboard.writeText('#{url(~p"/podcasts/#{@username}/#{@show.slug}/feed.xml")}')"}
                    class="px-3 py-1.5 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 text-white text-xs transition-colors"
                  >
                    {gettext("Copy")}
                  </button>
                  <a
                    href={~p"/podcasts/#{@username}/#{@show.slug}/feed.xml"}
                    class="px-3 py-1.5 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 text-white text-xs transition-colors"
                  >
                    {gettext("RSS feed")}
                  </a>
                </div>
              </div>
            </div>
          </header>

          <div :if={@episodes == []} class="text-gray-400">{gettext("No episodes yet.")}</div>

          <ul class="space-y-4">
            <li :for={episode <- @episodes} class="rounded-xl bg-white/5 border border-white/10 p-4">
              <.link
                navigate={~p"/podcasts/#{@username}/#{@show.slug}/episodes/#{episode.guid}"}
                class="font-semibold text-white hover:text-purple-300 transition-colors"
              >
                {episode.title}
              </.link>
              <p class="text-sm text-gray-400 mb-3 mt-1">{episode.description}</p>
              <.audio_player
                id={"player-#{episode.guid}"}
                src={~p"/podcasts/#{@username}/#{@show.slug}/episodes/#{episode.guid}/audio?#{[source: "web"]}"}
              />
            </li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
