defmodule PremiereEcoute.Donations.Balance do
  @moduledoc """
  Embedded schema representing the financial balance of a goal.

  Stored in the database and updated when donations/expenses are added or revoked.
  Excludes refunded donations and expenses from calculations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          collected_amount: Decimal.t(),
          spent_amount: Decimal.t(),
          remaining_amount: Decimal.t(),
          progress: float()
        }

  embedded_schema do
    field :collected_amount, :decimal
    field :spent_amount, :decimal
    field :remaining_amount, :decimal
    field :progress, :float
  end

  def changeset(balance, attrs) do
    balance
    |> cast(attrs, [:collected_amount, :spent_amount, :remaining_amount, :progress])
  end

  @doc """
  Creates a balance struct from collected and spent amounts with target.
  """
  def new(collected, spent, target) do
    remaining = Decimal.sub(collected, spent)
    progress = calculate_progress(collected, target)

    %__MODULE__{
      collected_amount: collected,
      spent_amount: spent,
      remaining_amount: remaining,
      progress: progress
    }
  end

  defp calculate_progress(_collected, target) when target in [nil, 0], do: 0.0

  defp calculate_progress(collected, target) do
    collected
    |> Decimal.div(target)
    |> Decimal.mult(100)
    |> Decimal.to_float()
  end
end
