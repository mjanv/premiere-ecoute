defmodule PremiereEcoute.Donations.Services.Donations do
  @moduledoc """
  Service module for managing donations to goals.

  Provides functions to:
  - Add donations to goals
  - Revoke donations and update goal balance
  """

  alias PremiereEcoute.Donations.{Donation, Goal}
  alias PremiereEcoute.Donations.Services.Balance
  alias PremiereEcoute.Repo

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
    |> Ecto.Multi.insert(
      :donation,
      Donation.changeset(
        %Donation{},
        attrs |> Map.put(:goal_id, goal.id) |> Map.put_new(:created_at, DateTime.utc_now()) |> Map.put_new(:payload, %{})
      )
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
      balance = Balance.compute_balance(goal)
      # Convert Balance struct to map for storage
      balance_map = Map.from_struct(balance)
      Goal.update(goal, %{balance: balance_map})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{donation: donation}} -> {:ok, donation}
      {:error, :donation, changeset, _} -> {:error, changeset}
      {:error, :update_balance, reason, _} -> {:error, reason}
    end
  end
end
