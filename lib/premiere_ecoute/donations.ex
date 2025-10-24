defmodule PremiereEcoute.Donations do
  @moduledoc """
  Context module for managing fundraising goals, donations, and expenses.

  Provides functions to:
  - Create and manage goals (only one can be active at a time)
  - Add and revoke donations from goals
  - Add and revoke expenses from goals
  - Compute goal balances (excluding refunded items)
  - Retrieve the current active goal with its balance
  """

  import Ecto.Query

  alias PremiereEcoute.Donations.{Balance, Donation, Expense, Goal}
  alias PremiereEcoute.Repo

  # Goal operations

  @doc """
  Creates a new fundraising goal.

  ## Examples

      iex> create_goal(%{title: "Server Hosting", target_amount: 100, currency: "USD", start_date: ~D[2025-01-01], end_date: ~D[2025-12-31]})
      {:ok, %Goal{}}

      iex> create_goal(%{title: "", target_amount: -10})
      {:error, %Ecto.Changeset{}}
  """
  def create_goal(attrs) do
    Goal.create(attrs)
  end

  @doc """
  Enables a goal and disables all other goals.
  Only one goal can be active at a time.

  ## Examples

      iex> enable_goal(goal)
      {:ok, %Goal{active: true}}
  """
  def enable_goal(%Goal{} = goal) do
    Ecto.Multi.new()
    |> Ecto.Multi.update_all(:disable_all, Goal, set: [active: false])
    |> Ecto.Multi.update(:enable_goal, Goal.changeset(goal, %{active: true}))
    |> Repo.transaction()
    |> case do
      {:ok, %{enable_goal: goal}} -> {:ok, goal}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Disables a goal.

  ## Examples

      iex> disable_goal(goal)
      {:ok, %Goal{active: false}}
  """
  def disable_goal(%Goal{} = goal) do
    Goal.update(goal, %{active: false})
  end

  @doc """
  Retrieves the currently active goal based on the active flag and today's date.
  Returns nil if no active goal is found within the current date range.

  ## Examples

      iex> get_current_goal()
      %Goal{active: true}

      iex> get_current_goal()
      nil
  """
  def get_current_goal do
    today = Date.utc_today()

    from(g in Goal,
      where: g.active == true,
      where: g.start_date <= ^today,
      where: g.end_date >= ^today,
      preload: [:donations, :expenses]
    )
    |> Repo.one()
  end

  # Donation operations

  @doc """
  Adds a donation to the specified goal and updates the goal's balance.

  ## Examples

      iex> add_donation(goal, %{amount: 50, currency: "USD", external_id: "txn_123", created_at: ~U[2025-01-15 10:00:00Z]})
      {:ok, %Donation{}}

      iex> add_donation(goal, %{amount: -10})
      {:error, %Ecto.Changeset{}}
  """
  def add_donation(%Goal{} = goal, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:donation, Donation.changeset(%Donation{}, attrs |> Map.put(:goal_id, goal.id) |> Map.put_new(:created_at, DateTime.utc_now()) |> Map.put_new(:payload, %{})))
    |> Ecto.Multi.run(:update_balance, fn _repo, _changes ->
      fresh_goal = Repo.preload(Goal.get(goal.id), [:donations, :expenses], force: true)
      balance = compute_balance(fresh_goal)
      Goal.update(fresh_goal, %{balance: Map.from_struct(balance)})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{donation: donation}} -> {:ok, donation}
      {:error, :donation, changeset, _} -> {:error, changeset}
      {:error, :update_balance, reason, _} -> {:error, reason}
    end
  end

  @doc """
  Revokes a donation by updating its status to :refunded and updates the goal's balance.
  Does not delete the donation record.

  ## Examples

      iex> revoke_donation(donation)
      {:ok, %Donation{status: :refunded}}
  """
  def revoke_donation(%Donation{} = donation) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:donation, Donation.changeset(donation, %{status: :refunded}))
    |> Ecto.Multi.run(:update_balance, fn _repo, _changes ->
      goal = Repo.preload(Goal.get(donation.goal_id), [:donations, :expenses], force: true)
      balance = compute_balance(goal)
      Goal.update(goal, %{balance: Map.from_struct(balance)})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{donation: donation}} -> {:ok, donation}
      {:error, :donation, changeset, _} -> {:error, changeset}
      {:error, :update_balance, reason, _} -> {:error, reason}
    end
  end

  # Expense operations

  @doc """
  Adds an expense to the specified goal and updates the goal's balance.

  ## Examples

      iex> add_expense(goal, %{title: "Server costs", category: "hosting", amount: 25, currency: "USD", incurred_at: ~U[2025-01-20 14:30:00Z]})
      {:ok, %Expense{}}

      iex> add_expense(goal, %{amount: -5})
      {:error, %Ecto.Changeset{}}
  """
  def add_expense(%Goal{} = goal, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:expense, Expense.changeset(%Expense{}, attrs |> Map.put(:goal_id, goal.id) |> Map.put_new(:incurred_at, DateTime.utc_now())))
    |> Ecto.Multi.run(:update_balance, fn _repo, _changes ->
      fresh_goal = Repo.preload(Goal.get(goal.id), [:donations, :expenses], force: true)
      balance = compute_balance(fresh_goal)
      Goal.update(fresh_goal, %{balance: Map.from_struct(balance)})
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
  def revoke_expense(%Expense{} = expense) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:expense, Expense.changeset(expense, %{status: :refunded}))
    |> Ecto.Multi.run(:update_balance, fn _repo, _changes ->
      goal = Repo.preload(Goal.get(expense.goal_id), [:donations, :expenses], force: true)
      balance = compute_balance(goal)
      Goal.update(goal, %{balance: Map.from_struct(balance)})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{expense: expense}} -> {:ok, expense}
      {:error, :expense, changeset, _} -> {:error, changeset}
      {:error, :update_balance, reason, _} -> {:error, reason}
    end
  end

  # Balance operations

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

  @doc """
  Retrieves the current active goal with its stored balance converted to Balance struct.

  ## Examples

      iex> get_current_goal_with_balance()
      %Goal{balance: %Balance{}}

      iex> get_current_goal_with_balance()
      nil
  """
  def get_current_goal_with_balance do
    case get_current_goal() do
      nil ->
        nil

      goal ->
        balance =
          if goal.balance != %{} do
            %Balance{
              collected_amount: string_to_decimal(goal.balance["collected_amount"]),
              spent_amount: string_to_decimal(goal.balance["spent_amount"]),
              remaining_amount: string_to_decimal(goal.balance["remaining_amount"]),
              progress: goal.balance["progress"]
            }
          else
            nil
          end

        %{goal | balance: balance}
    end
  end

  defp string_to_decimal(value) when is_binary(value), do: Decimal.new(value)
  defp string_to_decimal(value), do: value

  # Delegated functions for direct schema access
  defdelegate get_goal(id), to: Goal, as: :get
  defdelegate all_goals(clauses \\ []), to: Goal, as: :all
  defdelegate get_donation(id), to: Donation, as: :get
  defdelegate all_donations(clauses \\ []), to: Donation, as: :all
  defdelegate get_expense(id), to: Expense, as: :get
  defdelegate all_expenses(clauses \\ []), to: Expense, as: :all
end
