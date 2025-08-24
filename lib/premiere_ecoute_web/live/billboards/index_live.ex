defmodule PremiereEcouteWeb.Billboards.IndexLive do
  @moduledoc """
  LiveView for displaying all billboards created by a streamer.

  Shows billboards with their status, submission count, and action buttons.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Billboards

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket) do
    socket
    |> assign(:billboards, Billboards.all(where: [user_id: user.id]))
    |> assign(:current_user, user)
    |> then(fn socket -> {:ok, socket} end)
  end

  @impl true
  def handle_event("navigate", %{"billboard_id" => billboard_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/billboards/#{billboard_id}")}
  end

  # Helper functions
end
