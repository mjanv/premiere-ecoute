defmodule PremiereEcoute.Donations.Services.Donations do
  @moduledoc """
  Service module for managing donations to goals.

  Provides functions to:
  - Create donations with or without goals
  - Add donations to goals
  - Revoke donations and update goal balance
  """

  alias PremiereEcoute.Apis.FrankfurterApi
  alias PremiereEcoute.Donations.{Donation, Goal}
  alias PremiereEcoute.Donations.Services.{Balance, Goals}
  alias PremiereEcoute.Repo

  require Logger

  @doc """
  Creates a donation from webhook data.

  If a current active goal exists, attaches the donation to it.
  If currencies don't match, converts the donation amount to the goal's currency using Frankfurter API.
  The original payload is always preserved; only amount and currency fields are updated after conversion.
  Broadcasts a PubSub event on successful creation.

  ## Examples

      iex> create_donation(%{amount: 50, currency: "USD", external_id: "txn_123", payload: %{...}})
      {:ok, %Donation{}}

      iex> create_donation(%{amount: -10})
      {:error, %Ecto.Changeset{}}
  """
  def create_donation(attrs) do
    # Ensure defaults are set
    attrs =
      attrs
      |> Map.put_new(:created_at, DateTime.utc_now())
      |> Map.put_new(:provider, :buymeacoffee)
      |> Map.put_new(:status, :created)

    # Try to find current goal
    current_goal = Goals.get_current_goal()

    # Convert currency if needed and attach to goal
    {attrs, goal_id} =
      if current_goal do
        if current_goal.currency == attrs[:currency] do
          # Currencies match - no conversion needed
          {attrs, current_goal.id}
        else
          # Currencies don't match - convert amount
          case convert_currency(attrs[:amount], attrs[:currency], current_goal.currency) do
            {:ok, converted_amount} ->
              # Convert float to Decimal (Decimal.new only accepts integers/strings)
              converted_decimal =
                converted_amount
                |> Float.to_string()
                |> Decimal.new()

              attrs_with_conversion =
                attrs
                |> Map.put(:amount, converted_decimal)
                |> Map.put(:currency, current_goal.currency)

              Logger.info(
                "Currency converted: #{attrs[:amount]} #{attrs[:currency]} -> #{converted_amount} #{current_goal.currency}"
              )

              {attrs_with_conversion, current_goal.id}

            {:error, reason} ->
              Logger.warning(
                "Failed to convert currency from #{attrs[:currency]} to #{current_goal.currency}: #{inspect(reason)}"
              )

              # Create donation without goal if conversion fails
              {attrs, nil}
          end
        end
      else
        # No current goal - create donation without goal
        {attrs, nil}
      end

    attrs = if goal_id, do: Map.put(attrs, :goal_id, goal_id), else: attrs

    # Create the donation
    result =
      if goal_id do
        # Use add_donation for goals (with balance update)
        add_donation(current_goal, attrs)
      else
        # Create donation without goal
        %Donation{}
        |> Donation.changeset(attrs)
        |> Repo.insert()
      end

    # Broadcast event if successful
    case result do
      {:ok, donation} ->
        if goal_id do
          Phoenix.PubSub.broadcast(
            PremiereEcoute.PubSub,
            "donations",
            %{event: "donation_added", goal_id: goal_id}
          )
        end

        {:ok, donation}

      {:error, _} = error ->
        error
    end
  end

  defp convert_currency(amount, from_currency, to_currency) do
    amount_float =
      case amount do
        %Decimal{} -> Decimal.to_float(amount)
        num when is_number(num) -> num
      end

    case FrankfurterApi.convert(%{amount: amount_float, from: from_currency, to: to_currency}) do
      {:ok, %{amount: converted_amount}} -> {:ok, converted_amount}
      {:error, _} = error -> error
    end
  end

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
  Revokes a donation by updating its status to :refunded.
  If the donation is attached to a goal, updates the goal's balance.
  Does not delete the donation record.

  ## Examples

      iex> revoke_donation(donation)
      {:ok, %Donation{status: :refunded}}
  """
  def revoke_donation(%Donation{goal_id: nil} = donation) do
    # Donation not attached to a goal - just update status
    donation
    |> Donation.changeset(%{status: :refunded})
    |> Repo.update()
  end

  def revoke_donation(%Donation{goal_id: goal_id} = donation) when not is_nil(goal_id) do
    # Donation attached to a goal - update status and recalculate balance
    Ecto.Multi.new()
    |> Ecto.Multi.update(:donation, Donation.changeset(donation, %{status: :refunded}))
    |> Ecto.Multi.run(:update_balance, fn _repo, _changes ->
      goal = Repo.preload(Goal.get(goal_id), [:donations, :expenses], force: true)
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
