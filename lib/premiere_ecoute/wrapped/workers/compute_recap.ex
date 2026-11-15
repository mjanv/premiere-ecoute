defmodule PremiereEcoute.Wrapped.Workers.ComputeRecap do
  @moduledoc """
  Computes and stores the Wrapped recap of one user for a year.
  """

  use PremiereEcouteCore.Worker,
    queue: :wrapped,
    max_attempts: 3,
    unique: [period: 300, keys: [:user_id, :year], states: [:available, :scheduled, :executing, :retryable]]

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Wrapped.Services.ComputeRecap

  @impl true
  def perform(%Oban.Job{args: %{"user_id" => user_id, "year" => year}}) do
    case User.get(user_id) do
      nil -> :ok
      user -> with {:ok, _recap} <- ComputeRecap.compute(user, year), do: :ok
    end
  end
end
