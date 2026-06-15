defmodule PremiereEcouteWeb.Podcasts.EpisodeLive do
  @moduledoc """
  Public, shareable page for a single published episode: metadata, an in-page player, and a link
  back to the show.
  """

  use PremiereEcouteWeb, :live_view

  import PremiereEcouteWeb.Podcasts.Components

  alias PremiereEcoute.Podcasts
  alias PremiereEcoute.Podcasts.Show

  @impl true
  def mount(%{"username" => username, "show_slug" => slug, "guid" => guid}, _session, socket) do
    socket =
      with %Show{id: show_id} = show <- Podcasts.get_published_show(username, slug),
           %{} = episode <- Podcasts.get_published_episode(show_id, guid) do
        assign(socket, username: username, show: show, episode: episode)
      else
        _ -> assign(socket, username: username, show: nil, episode: nil)
      end

    {:ok, socket}
  end

  @impl true
  def render(%{episode: nil} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_page="podcasts">
      <div class="synthwave-bg min-h-screen text-white">
        <div class="max-w-3xl mx-auto px-6 py-12">
          <h1 class="text-xl font-semibold text-white">{gettext("Episode not found")}</h1>
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
          <.link
            navigate={~p"/podcasts/#{@username}/#{@show.slug}"}
            class="text-sm text-purple-300 hover:text-purple-200 transition-colors"
          >
            ← {@show.title}
          </.link>

          <h1 class="text-2xl font-bold text-white mt-2">{@episode.title}</h1>
          <div :if={@episode.season || @episode.episode_number} class="text-xs text-gray-400 mb-2">
            <span :if={@episode.season}>S{@episode.season}</span>
            <span :if={@episode.episode_number}>E{@episode.episode_number}</span>
          </div>
          <p class="text-gray-300 mt-2 mb-4 whitespace-pre-line">{@episode.description}</p>

          <div class="mb-4">
            <.audio_player
              id={"player-#{@episode.guid}"}
              src={~p"/podcasts/#{@username}/#{@show.slug}/episodes/#{@episode.guid}/audio?#{[source: "web"]}"}
            />
          </div>

          <button
            type="button"
            onclick={"navigator.clipboard.writeText('#{url(~p"/podcasts/#{@username}/#{@show.slug}/episodes/#{@episode.guid}")}')"}
            class="px-3 py-1.5 rounded-lg bg-white/5 border border-white/10 hover:bg-white/10 text-white text-xs transition-colors"
          >
            {gettext("Copy link")}
          </button>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
