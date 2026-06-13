defmodule PremiereEcouteWeb.Podcasts.EpisodeLive do
  @moduledoc """
  Public, shareable page for a single published episode: metadata, an in-page player, and a link
  back to the show.
  """

  use PremiereEcouteWeb, :live_view

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
    <div class="max-w-3xl mx-auto p-6">
      <h1 class="text-xl font-semibold">{gettext("Episode not found")}</h1>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto p-6">
      <.link navigate={~p"/podcasts/#{@username}/#{@show.slug}"} class="text-sm text-indigo-600">
        ← {@show.title}
      </.link>

      <h1 class="text-2xl font-bold mt-2">{@episode.title}</h1>
      <div :if={@episode.season || @episode.episode_number} class="text-xs text-gray-500 mb-2">
        <span :if={@episode.season}>S{@episode.season}</span>
        <span :if={@episode.episode_number}>E{@episode.episode_number}</span>
      </div>
      <p class="text-gray-500 mt-2 mb-4 whitespace-pre-line">{@episode.description}</p>

      <audio
        controls
        preload="none"
        class="w-full mb-4"
        src={~p"/podcasts/#{@username}/#{@show.slug}/episodes/#{@episode.guid}/audio?#{[source: "web"]}"}
      >
      </audio>

      <button
        type="button"
        onclick={"navigator.clipboard.writeText('#{url(~p"/podcasts/#{@username}/#{@show.slug}/episodes/#{@episode.guid}")}')"}
        class="px-2 py-1 rounded border text-xs"
      >
        {gettext("Copy link")}
      </button>
    </div>
    """
  end
end
