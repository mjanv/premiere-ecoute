defmodule PremiereEcoute.Wrapped.Cards.NextAlbums do
  @moduledoc """
  Next albums: the albums ranked 2 to 5 by the viewer's own score. Skipped with fewer than two of them.
  """

  @behaviour PremiereEcoute.Wrapped.Card

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Listen

  @impl true
  def compute(listens) do
    case listens |> Listen.albums() |> Card.top(5) do
      [_, second, _ | _] = top ->
        %Card{
          type: :next_albums,
          data: %{albums: top |> tl() |> Enum.map(&Card.scored/1)},
          appearance: Card.appearance(second),
          preview: Card.preview(second)
        }

      _ ->
        :skip
    end
  end
end
