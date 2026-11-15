defmodule PremiereEcoute.Wrapped.Cards.Recap do
  @moduledoc """
  Recap: top 3 albums, album count and total minutes on one share card.
  """

  @behaviour PremiereEcoute.Wrapped.Card

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Listen

  @impl true
  def compute(listens) do
    albums = Listen.albums(listens)

    case Card.top(albums) do
      [first, _, _] = top ->
        %Card{
          type: :recap,
          data: %{top: Enum.map(top, &Card.scored/1), albums: length(albums), minutes: Card.minutes(albums)},
          appearance: Card.appearance(first),
          preview: Card.preview(first)
        }

      _ ->
        :skip
    end
  end
end
