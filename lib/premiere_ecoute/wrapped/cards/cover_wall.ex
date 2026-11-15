defmodule PremiereEcoute.Wrapped.Cards.CoverWall do
  @moduledoc """
  Cover wall: the covers of the albums voted on, in chronological order.
  """

  @behaviour PremiereEcoute.Wrapped.Card

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Listen

  @min_covers 4

  @impl true
  def compute(listens) do
    case listens |> Listen.albums() |> Enum.filter(&Listen.cover_url/1) do
      covers when length(covers) >= @min_covers ->
        %Card{
          type: :cover_wall,
          data: %{covers: Enum.map(covers, &Card.album/1)},
          appearance: Card.appearance(hd(covers)),
          preview: nil
        }

      _ ->
        :skip
    end
  end
end
