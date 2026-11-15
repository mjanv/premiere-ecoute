defmodule PremiereEcoute.Wrapped.Cards.TopAlbum do
  @moduledoc """
  Top album: the album with the viewer's best score.
  """

  @behaviour PremiereEcoute.Wrapped.Card

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Listen

  @impl true
  def compute(listens) do
    case listens |> Listen.albums() |> Card.top(1) do
      [first] ->
        %Card{
          type: :top_album,
          data: %{album: Card.scored(first)},
          appearance: Card.appearance(first),
          preview: Card.preview(first)
        }

      [] ->
        :skip
    end
  end
end
