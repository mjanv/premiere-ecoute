defmodule PremiereEcouteWeb.Discography.SingleLive do
  @moduledoc """
  Single detail page — shows single metadata and listening sessions that used it.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Discography
  alias PremiereEcoute.Sessions.ListeningSession

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    single = Discography.get_single_by_slug(slug)

    if is_nil(single) do
      {:ok, push_navigate(socket, to: ~p"/discography/singles")}
    else
      sessions = ListeningSession.list_for_single(single.id)

      {:ok,
       socket
       |> assign(:single, single)
       |> assign(:sessions, sessions)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}
end
