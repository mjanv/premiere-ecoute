defmodule PremiereEcoute.Donations.Services.Goals do
  @moduledoc """
  Service module for managing fundraising goals.

  Provides functions to:
  - Create and manage goals (only one can be active at a time)
  - Enable and disable goals
  - Retrieve goal information
  """

  import Ecto.Query

  alias PremiereEcoute.Donations.Goal
  alias PremiereEcoute.Repo

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
end
