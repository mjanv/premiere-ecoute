defmodule PremiereEcouteWeb.Admin.Donations.GoalLive do
  @moduledoc false

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Donations
  alias PremiereEcoute.Repo

  def mount(%{"id" => goal_id}, _session, socket) do
    goal = Donations.get_goal(goal_id) |> Repo.preload([:donations, :expenses])
    balance = Donations.compute_balance(goal)

    socket
    |> assign(:goal, goal)
    |> assign(:balance, balance)
    |> assign(:show_expense_modal, false)
    |> assign(:expense_form, nil)
    |> then(fn socket -> {:ok, socket} end)
  end

  def handle_event("show_expense_modal", _params, socket) do
    changeset = Donations.Expense.changeset(%Donations.Expense{}, %{})

    socket
    |> assign(:show_expense_modal, true)
    |> assign(:expense_form, to_form(changeset))
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("close_expense_modal", _params, socket) do
    socket
    |> assign(:show_expense_modal, false)
    |> assign(:expense_form, nil)
    |> then(fn socket -> {:noreply, socket} end)
  end

  def handle_event("modal_content_click", _params, socket), do: {:noreply, socket}

  def handle_event("validate_expense_form", %{"expense" => expense_params}, socket) do
    form = to_form(expense_params, action: :validate)
    {:noreply, assign(socket, expense_form: form)}
  end

  def handle_event("save_expense", %{"expense" => expense_params}, socket) do
    # Also add goal's currency to ensure expense currency matches goal currency
    expense_params =
      expense_params
      |> Map.put("amount", Decimal.new(expense_params["amount"]))
      |> Map.put("currency", socket.assigns.goal.currency)
      |> convert_date_to_datetime()

    case Donations.add_expense(socket.assigns.goal, expense_params) do
      {:ok, _expense} ->
        goal = Donations.get_goal(socket.assigns.goal.id) |> Repo.preload([:donations, :expenses], force: true)
        balance = Donations.compute_balance(goal)

        socket
        |> assign(:goal, goal)
        |> assign(:balance, balance)
        |> assign(:show_expense_modal, false)
        |> assign(:expense_form, nil)
        |> put_flash(:info, gettext("Expense has been added successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, changeset} ->
        form = to_form(changeset)

        socket
        |> assign(:expense_form, form)
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_event("delete_expense", %{"expense_id" => expense_id}, socket) do
    expense = Donations.get_expense(expense_id)

    case Donations.revoke_expense(expense) do
      {:ok, _} ->
        goal = Donations.get_goal(socket.assigns.goal.id) |> Repo.preload([:donations, :expenses], force: true)
        balance = Donations.compute_balance(goal)

        socket
        |> assign(:goal, goal)
        |> assign(:balance, balance)
        |> put_flash(:info, gettext("Expense has been deleted successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _reason} ->
        socket
        |> put_flash(:error, gettext("Failed to delete expense"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  def handle_event("delete_donation", %{"donation_id" => donation_id}, socket) do
    donation = Donations.get_donation(donation_id)

    case Donations.revoke_donation(donation) do
      {:ok, _} ->
        goal = Donations.get_goal(socket.assigns.goal.id) |> Repo.preload([:donations, :expenses], force: true)
        balance = Donations.compute_balance(goal)

        socket
        |> assign(:goal, goal)
        |> assign(:balance, balance)
        |> put_flash(:info, gettext("Donation has been revoked successfully"))
        |> then(fn socket -> {:noreply, socket} end)

      {:error, _reason} ->
        socket
        |> put_flash(:error, gettext("Failed to revoke donation"))
        |> then(fn socket -> {:noreply, socket} end)
    end
  end

  # Private helper to convert date string to DateTime
  defp convert_date_to_datetime(params) do
    case params["incurred_at"] do
      date_string when is_binary(date_string) and byte_size(date_string) > 0 ->
        case Date.from_iso8601(date_string) do
          {:ok, date} ->
            datetime = DateTime.new!(date, Time.new!(0, 0, 0), "Etc/UTC")
            Map.put(params, "incurred_at", datetime)

          {:error, _reason} ->
            params
        end

      _ ->
        params
    end
  end
end
