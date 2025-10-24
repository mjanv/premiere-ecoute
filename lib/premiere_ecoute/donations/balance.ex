defmodule PremiereEcoute.Donations.Balance do
  @moduledoc """
  Embedded schema representing the financial balance of a goal.

  Computed on-demand and attached as a virtual field to Goal structs.
  Excludes refunded donations and expenses from calculations.
  """

  use PremiereEcouteCore.Aggregate.Object

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
