defmodule PremiereEcouteWeb.Admin.Donations.DonationsLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Donations
  alias PremiereEcoute.Donations.Goal
  alias PremiereEcoute.Repo

  def mount(_params, _session, socket) do
    goals = Donations.all_goals(order_by: [desc: :start_date])

    socket
    |> assign(:goals, goals)
    |> assign(:selected_goal, nil)
    |> assign(:show_goal_modal, false)
    |> assign(:modal_action, :create)
    |> assign(:goal_form, nil)
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_event("show_goal_modal", _params, socket) do
    socket
    |> assign(:modal_action, :create)
    |> assign(:selected_goal, nil)
    |> assign(:show_goal_modal, true)
    |> assign(:goal_form, to_form(%{}))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("edit_goal", %{"goal_id" => goal_id}, socket) do
    goal = Donations.get_goal(goal_id)

    socket
    |> assign(:modal_action, :edit)
    |> assign(:selected_goal, goal)
    |> assign(:show_goal_modal, true)
    |> assign(
      :goal_form,
      to_form(%{
        "title" => goal.title,
        "description" => goal.description,
        "target_amount" => Decimal.to_string(goal.target_amount),
        "currency" => goal.currency,
        "start_date" => goal.start_date,
        "end_date" => goal.end_date
      })
    )
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("close_goal_modal", _params, socket) do
    socket
    |> assign(:selected_goal, nil)
    |> assign(:show_goal_modal, false)
    |> assign(:goal_form, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("modal_content_click", _params, socket), do: {:noreply, socket}

  def handle_event("validate_goal_form", %{"goal" => goal_params}, socket) do
    # Update form with validation feedback without saving
    form = to_form(goal_params, action: :validate)
    {:noreply, assign(socket, goal_form: form)}
  end

  def handle_event("save_goal", %{"goal" => goal_params}, socket) do
    case socket.assigns.modal_action do
      :create -> create_goal(socket, goal_params)
      :edit -> update_goal(socket, goal_params)
    end
  end

  def handle_event("enable_goal", %{"goal_id" => goal_id}, socket) do
    goal = Donations.get_goal(goal_id)

    case Donations.enable_goal(goal) do
      {:ok, _} ->
        goals = fetch_goals()

        socket
        |> assign(:goals, goals)
        |> put_flash(:info, gettext("Goal has been activated successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _reason} ->
        socket
        |> put_flash(:error, gettext("Failed to activate goal"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_event("disable_goal", %{"goal_id" => goal_id}, socket) do
    goal = Donations.get_goal(goal_id)

    case Donations.disable_goal(goal) do
      {:ok, _} ->
        goals = fetch_goals()

        socket
        |> assign(:goals, goals)
        |> put_flash(:info, gettext("Goal has been deactivated successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _reason} ->
        socket
        |> put_flash(:error, gettext("Failed to deactivate goal"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_event("confirm_delete_goal", %{"goal_id" => goal_id}, socket) do
    goal = Donations.get_goal(goal_id)

    case Repo.delete(goal) do
      {:ok, _} ->
        goals = fetch_goals()

        socket
        |> assign(:goals, goals)
        |> assign(:selected_goal, nil)
        |> assign(:show_goal_modal, false)
        |> put_flash(:info, gettext("Goal has been deleted successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _reason} ->
        socket
        |> put_flash(:error, gettext("Failed to delete goal"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  defp create_goal(socket, goal_params) do
    goal_params = Map.put(goal_params, "target_amount", Decimal.new(goal_params["target_amount"]))

    case Donations.create_goal(goal_params) do
      {:ok, _goal} ->
        goals = fetch_goals()

        socket
        |> assign(:goals, goals)
        |> assign(:selected_goal, nil)
        |> assign(:show_goal_modal, false)
        |> assign(:goal_form, nil)
        |> put_flash(:info, gettext("Goal has been created successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, changeset} ->
        form = to_form(changeset)

        socket
        |> assign(:goal_form, form)
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  defp update_goal(socket, goal_params) do
    goal = socket.assigns.selected_goal
    goal_params = Map.put(goal_params, "target_amount", Decimal.new(goal_params["target_amount"]))

    case Goal.update(goal, goal_params) do
      {:ok, _updated_goal} ->
        goals = fetch_goals()

        socket
        |> assign(:goals, goals)
        |> assign(:selected_goal, nil)
        |> assign(:show_goal_modal, false)
        |> assign(:goal_form, nil)
        |> put_flash(:info, gettext("Goal has been updated successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, changeset} ->
        form = to_form(changeset)

        socket
        |> assign(:goal_form, form)
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  defp fetch_goals do
    Donations.all_goals(order_by: [desc: :start_date])
  end
end
