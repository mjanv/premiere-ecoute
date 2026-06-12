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
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-3xl mx-auto p-6">
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold">{gettext("My podcasts")}</h1>
          <.link navigate={~p"/studio/podcasts/new"} class="px-4 py-2 rounded bg-indigo-600 text-white">
            {gettext("New show")}
          </.link>
        </div>

        <div :if={@shows == []} class="text-gray-500">{gettext("You have no podcast shows yet.")}</div>

        <ul class="space-y-3">
          <li :for={show <- @shows} class="border rounded-lg p-4 flex items-center justify-between">
            <.link navigate={~p"/studio/podcasts/#{show.id}"} class="flex items-center gap-3">
              <img :if={show.cover_url} src={show.cover_url} alt={show.title} class="w-12 h-12 rounded object-cover" />
              <span class="font-semibold">{show.title}</span>
            </.link>
            <span class={[
              "text-xs px-2 py-1 rounded",
              if(show.published, do: "bg-green-100 text-green-700", else: "bg-gray-100 text-gray-600")
            ]}>
              {if show.published, do: gettext("Published"), else: gettext("Draft")}
            </span>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end
end
