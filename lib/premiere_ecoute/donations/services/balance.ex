defmodule PremiereEcoute.Donations.Services.Balance do
  @moduledoc """
  Service module for managing goal balances.

  Provides functions to:
  - Compute goal balances from donations and expenses
  """

  alias PremiereEcoute.Donations.{Balance, Goal}
  alias PremiereEcoute.Repo

  @doc """
  Computes the balance for a goal, excluding refunded donations and expenses.

  Returns a Balance struct with:
  - collected_amount: Sum of non-refunded donations
  - spent_amount: Sum of non-refunded expenses
  - remaining_amount: collected_amount - spent_amount
  - progress: (collected_amount / target_amount) * 100

  ## Examples

      iex> compute_balance(goal)
      %Balance{collected_amount: Decimal.new(100), spent_amount: Decimal.new(25), remaining_amount: Decimal.new(75), progress: 50.0}
  """
  def compute_balance(%Goal{} = goal) do
    goal = Repo.preload(goal, [:donations, :expenses], force: true)

    collected =
      goal.donations
      |> Enum.filter(&(&1.status == :created))
      |> Enum.map(& &1.amount)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    spent =
      goal.expenses
      |> Enum.filter(&(&1.status in [:created, :paid]))
      |> Enum.map(& &1.amount)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    Balance.new(collected, spent, goal.target_amount)
  end
end
