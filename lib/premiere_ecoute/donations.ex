defmodule PremiereEcoute.Donations do
  @moduledoc """
  Context module for managing fundraising goals, donations, and expenses.

  Delegates business logic to service modules while providing a unified API for the rest of the application.
  """

  alias PremiereEcoute.Donations.{Donation, Expense, Goal}

  @service PremiereEcoute.Donations.Services.Goals
  defdelegate create_goal(attrs), to: @service
  defdelegate enable_goal(goal), to: @service
  defdelegate disable_goal(goal), to: @service
  defdelegate get_current_goal(), to: @service

  @service PremiereEcoute.Donations.Services.Donations
  defdelegate add_donation(goal, attrs), to: @service
  defdelegate revoke_donation(donation), to: @service

  @service PremiereEcoute.Donations.Services.Expenses
  defdelegate add_expense(goal, attrs), to: @service
  defdelegate revoke_expense(expense), to: @service

  @service PremiereEcoute.Donations.Services.Balance
  defdelegate compute_balance(goal), to: @service

  defdelegate get_goal(id), to: Goal, as: :get
  defdelegate all_goals(clauses \\ []), to: Goal, as: :all
  defdelegate get_donation(id), to: Donation, as: :get
  defdelegate all_donations(clauses \\ []), to: Donation, as: :all
  defdelegate get_expense(id), to: Expense, as: :get
  defdelegate all_expenses(clauses \\ []), to: Expense, as: :all
end
