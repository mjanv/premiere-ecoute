defmodule PremiereEcoute.Donations.Services.Expenses do
  @moduledoc """
  Service module for managing expenses against goals.

  Provides functions to:
  - Add expenses to goals
  - Revoke expenses and update goal balance
  """

  alias PremiereEcoute.Donations.{Expense, Goal}
  alias PremiereEcoute.Donations.Services.Balance
  alias PremiereEcoute.Repo

  @doc """
  Adds an expense to the specified goal and updates the goal's balance.

  ## Examples

      iex> add_expense(goal, %{title: "Server costs", category: "hosting", amount: 25, currency: "USD", incurred_at: ~U[2025-01-20 14:30:00Z]})
      {:ok, %Expense{}}

      iex> add_expense(goal, %{amount: -5})
      {:error, %Ecto.Changeset{}}
  """
  @spec add_expense(Goal.t(), map()) :: {:ok, Expense.t()} | {:error, Ecto.Changeset.t() | term()}
  def add_expense(%Goal{} = goal, attrs) do
    attrs = stringify_keys(attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :expense,
      Expense.changeset(%Expense{}, attrs |> Map.put("goal_id", goal.id) |> Map.put_new("incurred_at", DateTime.utc_now()))
    )
    |> Ecto.Multi.run(:update_balance, fn _repo, _changes ->
      fresh_goal = Repo.preload(Goal.get(goal.id), [:donations, :expenses], force: true)
      balance = Balance.compute_balance(fresh_goal)
      # Convert Balance struct to map for storage
      balance_map = Map.from_struct(balance)
      Goal.update(fresh_goal, %{balance: balance_map})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{expense: expense}} -> {:ok, expense}
      {:error, :expense, changeset, _} -> {:error, changeset}
      {:error, :update_balance, reason, _} -> {:error, reason}
    end
  end

  @doc """
  Revokes an expense by updating its status to :refunded and updates the goal's balance.
  Does not delete the expense record.

  ## Examples

      iex> revoke_expense(expense)
      {:ok, %Expense{status: :refunded}}
  """
  @spec revoke_expense(Expense.t()) :: {:ok, Expense.t()} | {:error, Ecto.Changeset.t() | term()}
  def revoke_expense(%Expense{} = expense) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:expense, Expense.changeset(expense, %{status: :refunded}))
    |> Ecto.Multi.run(:update_balance, fn _repo, _changes ->
      goal = Repo.preload(Goal.get(expense.goal_id), [:donations, :expenses], force: true)
      balance = Balance.compute_balance(goal)
      # Convert Balance struct to map for storage
      balance_map = Map.from_struct(balance)
      Goal.update(goal, %{balance: balance_map})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{expense: expense}} -> {:ok, expense}
      {:error, :expense, changeset, _} -> {:error, changeset}
      {:error, :update_balance, reason, _} -> {:error, reason}
    end
  end

  # Private helper to normalize atom keys to string keys
  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end
