defmodule PremiereEcouteWeb.Admin.Donations.OverlayLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Donations
  alias PremiereEcoute.Repo

  def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "donations")

    goal = Donations.get_current_goal()
    balance = if goal, do: Donations.compute_balance(goal), else: nil
    last_donation = if goal, do: Donations.last_donation(goal), else: nil

    socket
    |> assign(:goal, goal)
    |> assign(:balance, balance)
    |> assign(:last_donation, last_donation)
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_info(%{event: "donation_added", goal_id: goal_id}, socket) do
    # Refresh goal and balance when a donation is added
    goal = Donations.get_goal(goal_id) |> Repo.preload([:donations, :expenses], force: true)
    balance = if goal, do: Donations.compute_balance(goal), else: nil
    last_donation = Donations.last_donation(goal_id)

    socket
    |> assign(:goal, goal)
    |> assign(:balance, balance)
    |> assign(:last_donation, last_donation)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_info(_, socket), do: {:noreply, socket}
end
