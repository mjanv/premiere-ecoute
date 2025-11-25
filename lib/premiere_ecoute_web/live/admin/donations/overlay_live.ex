defmodule PremiereEcouteWeb.Admin.Donations.OverlayLive do
  @moduledoc """
  Donations overlay LiveView for streaming.

  Displays current donation goal progress with real-time updates via PubSub, showing goal balance and last donation for OBS/streaming overlays.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Donations

  def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "donations")

    goal = Donations.get_current_goal()
    # Use the stored balance from the database instead of computing it
    # The balance is updated when donations/expenses are added/revoked
    balance = if goal, do: goal.balance, else: nil
    last_donation = if goal, do: Donations.last_donation(goal), else: nil

    socket
    |> assign(:goal, goal)
    |> assign(:balance, balance)
    |> assign(:last_donation, last_donation)
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_info(%{event: "donation_added", goal_id: goal_id}, socket) do
    # Refresh goal when a donation is added
    # The balance is already updated in the database by the donation service
    goal = Donations.get_goal(goal_id)
    balance = if goal, do: goal.balance, else: nil
    last_donation = Donations.last_donation(goal_id)

    socket
    |> assign(:goal, goal)
    |> assign(:balance, balance)
    |> assign(:last_donation, last_donation)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_info(_, socket), do: {:noreply, socket}
end
