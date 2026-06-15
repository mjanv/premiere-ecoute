defmodule PremiereEcouteWeb.Podcasts.ShowsLive do
  @moduledoc """
  Public index of a streamer's published podcast shows.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Podcasts

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    shows =
      case Accounts.get_user_by_username(username) do
        nil -> []
        user -> user |> Podcasts.shows_for_user() |> Enum.filter(& &1.published)
      end

    {:ok, assign(socket, username: username, shows: shows)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_page="podcasts">
      <div class="synthwave-bg min-h-screen text-white">
        <div class="max-w-3xl mx-auto px-6 py-12">
          <h1 class="text-2xl font-bold text-white mb-6">
            {gettext("Podcasts by %{username}", username: @username)}
          </h1>

          <div :if={@shows == []} class="text-gray-400">{gettext("No podcasts published yet.")}</div>

          <ul class="space-y-4">
            <li
              :for={show <- @shows}
              class="rounded-xl bg-white/5 border border-white/10 hover:border-purple-500/50 hover:bg-white/10 transition-colors"
            >
              <.link navigate={~p"/podcasts/#{@username}/#{show.slug}"} class="flex items-center gap-4 p-4">
                <img
                  :if={show.cover_key}
                  src={~p"/podcasts/shows/#{show.id}/cover"}
                  alt={show.title}
                  class="w-16 h-16 rounded-lg object-cover flex-shrink-0"
                />
                <div class="min-w-0">
                  <div class="font-semibold text-white truncate">{show.title}</div>
                  <div class="text-sm text-gray-400 line-clamp-2">{show.description}</div>
                </div>
              </.link>
            </li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
