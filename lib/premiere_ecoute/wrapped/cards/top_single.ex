defmodule PremiereEcoute.Wrapped.Cards.TopSingle do
  @moduledoc """
  Top single: the single with the viewer's best score.
  """

  @behaviour PremiereEcoute.Wrapped.Card

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Listen

  @impl true
  def compute(listens) do
    case listens |> Listen.singles() |> Card.top(1) do
      [first] ->
        %Card{
          type: :top_single,
          data: %{single: Card.scored(first)},
          appearance: Card.appearance(first),
          preview: Card.preview(first)
        }

      [] ->
        :skip
    end
  end
end
