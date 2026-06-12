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
    reports = Map.new(shows, fn s -> {s.id, Podcasts.report_count(s)} end)
    assign(socket, shows: shows, counts: counts, reports: reports)
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
      <div class="max-w-4xl mx-auto p-6">
        <h1 class="text-2xl font-bold mb-6">{gettext("Podcast moderation")}</h1>

        <div :if={@shows == []} class="text-gray-500">{gettext("No shows.")}</div>

        <table :if={@shows != []} class="w-full text-sm">
          <thead>
            <tr class="text-left border-b">
              <th class="py-2">{gettext("Show")}</th>
              <th>{gettext("Owner")}</th>
              <th>{gettext("Episodes")}</th>
              <th>{gettext("Reports")}</th>
              <th>{gettext("Status")}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={show <- @shows} class="border-b">
              <td class="py-2 font-medium">{show.title}</td>
              <td>{show.user && show.user.username}</td>
              <td>{@counts[show.id]}</td>
              <td class={if @reports[show.id] > 0, do: "text-red-600 font-semibold", else: ""}>{@reports[show.id]}</td>
              <td>{if show.published, do: gettext("Published"), else: gettext("Draft")}</td>
              <td class="text-right">
                <button
                  :if={show.published}
                  phx-click="unpublish"
                  phx-value-id={show.id}
                  class="px-2 py-1 rounded border text-xs mr-1"
                >
                  {gettext("Unpublish")}
                </button>
                <button
                  phx-click="delete"
                  phx-value-id={show.id}
                  data-confirm={gettext("Delete this show and all its episodes?")}
                  class="px-2 py-1 rounded border border-red-300 text-red-600 text-xs"
                >
                  {gettext("Delete")}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end
end
