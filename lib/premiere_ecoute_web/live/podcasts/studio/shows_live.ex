defmodule PremiereEcouteWeb.Podcasts.Studio.ShowsLive do
  @moduledoc """
  Streamer studio: list of the current streamer's own podcast shows (published + drafts).
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Podcasts

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: scope}} = socket) do
    {:ok, assign(socket, shows: Podcasts.shows_for_user(scope.user))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_page="podcasts">
      <div class="synthwave-bg min-h-screen text-white">
        <div class="max-w-3xl mx-auto px-6 py-12">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold text-white">{gettext("My podcasts")}</h1>
            <.link
              navigate={~p"/studio/podcasts/new"}
              class="px-4 py-2 rounded-lg bg-purple-600 hover:bg-purple-700 text-white font-medium transition-colors"
            >
              {gettext("New show")}
            </.link>
          </div>

          <div :if={@shows == []} class="text-gray-400">{gettext("You have no podcast shows yet.")}</div>

          <ul class="space-y-3">
            <li
              :for={show <- @shows}
              class="rounded-xl bg-white/5 border border-white/10 hover:border-purple-500/50 hover:bg-white/10 transition-colors p-4 flex items-center justify-between gap-3"
            >
              <.link navigate={~p"/studio/podcasts/#{show.id}"} class="flex items-center gap-3 min-w-0">
                <img
                  :if={show.cover_key}
                  src={~p"/podcasts/shows/#{show.id}/cover"}
                  alt={show.title}
                  class="w-12 h-12 rounded-lg object-cover flex-shrink-0"
                />
                <span class="font-semibold text-white truncate">{show.title}</span>
              </.link>
              <span class={[
                "text-xs px-2.5 py-1 rounded border flex-shrink-0",
                if(show.published,
                  do: "bg-green-500/15 text-green-300 border-green-500/30",
                  else: "bg-white/5 text-gray-300 border-white/10"
                )
              ]}>
                {if show.published, do: gettext("Published"), else: gettext("Draft")}
              </span>
            </li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
