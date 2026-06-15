defmodule PremiereEcouteWeb.Admin.PodcastsLive do
  @moduledoc """
  Admin moderation for podcasts: lists every show with its owner, and allows takedown (unpublish)
  or deletion. Feeds are world-readable, so this is the governance surface for abuse/DMCA.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Podcasts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load(socket)}
  end

  defp load(socket) do
    shows = Podcasts.all_shows()
    counts = Map.new(shows, fn s -> {s.id, length(Podcasts.episodes_for_show(s))} end)
    assign(socket, shows: shows, counts: counts)
  end

  @impl true
  def handle_event("unpublish", %{"id" => id}, socket) do
    {:noreply, act(socket, id, &Podcasts.unpublish_show/1, gettext("Show unpublished"))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, act(socket, id, &Podcasts.delete_show/1, gettext("Show deleted"))}
  end

  defp act(socket, id, fun, message) do
    show = Enum.find(socket.assigns.shows, &(to_string(&1.id) == id))

    case show && fun.(show) do
      {:ok, _} -> socket |> put_flash(:info, message) |> load()
      _ -> put_flash(socket, :error, gettext("Action failed"))
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="bg-gray-900 min-h-screen text-white">
        <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <h1 class="text-2xl font-bold text-white mb-6">{gettext("Podcast moderation")}</h1>

          <div :if={@shows == []} class="text-gray-400">{gettext("No shows.")}</div>

          <div :if={@shows != []} class="rounded-xl bg-gray-800 border border-gray-700 overflow-hidden">
            <table class="w-full text-sm">
              <thead>
                <tr class="text-left text-gray-400 border-b border-gray-700">
                  <th class="px-4 py-3 font-medium">{gettext("Show")}</th>
                  <th class="px-4 py-3 font-medium">{gettext("Owner")}</th>
                  <th class="px-4 py-3 font-medium">{gettext("Episodes")}</th>
                  <th class="px-4 py-3 font-medium">{gettext("Status")}</th>
                  <th class="px-4 py-3"></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={show <- @shows} class="border-b border-gray-700/50 last:border-0">
                  <td class="px-4 py-3 font-medium text-white">{show.title}</td>
                  <td class="px-4 py-3 text-gray-300">{show.user && show.user.username}</td>
                  <td class="px-4 py-3 text-gray-300">{@counts[show.id]}</td>
                  <td class="px-4 py-3 text-gray-300">
                    {if show.published, do: gettext("Published"), else: gettext("Draft")}
                  </td>
                  <td class="px-4 py-3 text-right whitespace-nowrap">
                    <button
                      :if={show.published}
                      phx-click="unpublish"
                      phx-value-id={show.id}
                      class="px-2.5 py-1 rounded-lg bg-gray-700 hover:bg-gray-600 text-white text-xs mr-1 transition-colors"
                    >
                      {gettext("Unpublish")}
                    </button>
                    <button
                      phx-click="delete"
                      phx-value-id={show.id}
                      data-confirm={gettext("Delete this show and all its episodes?")}
                      class="px-2.5 py-1 rounded-lg bg-red-600/20 hover:bg-red-600/40 text-red-400 hover:text-red-300 text-xs transition-colors"
                    >
                      {gettext("Delete")}
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
