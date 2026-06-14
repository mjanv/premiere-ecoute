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
    <div class="max-w-3xl mx-auto p-6">
      <h1 class="text-2xl font-bold mb-6">{gettext("Podcasts by %{username}", username: @username)}</h1>

      <div :if={@shows == []} class="text-gray-500">{gettext("No podcasts published yet.")}</div>

      <ul class="space-y-4">
        <li :for={show <- @shows} class="border rounded-lg p-4">
          <.link navigate={~p"/podcasts/#{@username}/#{show.slug}"} class="flex items-center gap-4">
            <img
              :if={show.cover_key}
              src={~p"/podcasts/shows/#{show.id}/cover"}
              alt={show.title}
              class="w-16 h-16 rounded object-cover"
            />
            <div>
              <div class="font-semibold">{show.title}</div>
              <div class="text-sm text-gray-500">{show.description}</div>
            </div>
          </.link>
        </li>
      </ul>
    </div>
    """
  end
end
