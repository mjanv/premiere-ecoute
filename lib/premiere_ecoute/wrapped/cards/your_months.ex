defmodule PremiereEcoute.Wrapped.Cards.YourMonths do
  @moduledoc """
  Your months: the albums of the year counted month by month, and the busiest month.

  An album counts in the month of its first vote. Skipped when the whole year fits in one month.
  """

  @behaviour PremiereEcoute.Wrapped.Card

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Listen

  @impl true
  def compute(listens) do
    by_month = listens |> Listen.albums() |> Enum.group_by(& &1.result.voted_at.month)

    if map_size(by_month) < 2 do
      :skip
    else
      # The earliest month wins a tie
      {busiest, [first | _]} = Enum.max_by(by_month, fn {month, listens} -> {length(listens), -month} end)

      %Card{
        type: :your_months,
        data: %{months: Enum.map(1..12, &length(Map.get(by_month, &1, []))), busiest: busiest},
        appearance: Card.appearance(first),
        preview: Card.preview(first)
      }
    end
  end
end
