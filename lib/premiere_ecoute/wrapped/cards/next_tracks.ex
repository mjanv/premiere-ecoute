defmodule PremiereEcoute.Wrapped.Cards.NextTracks do
  @moduledoc """
  Next tracks: the tracks ranked 2 to 5, one per album. Skipped with fewer than two of them.
  """

  @behaviour PremiereEcoute.Wrapped.Card

  alias PremiereEcoute.Wrapped.Card

  @impl true
  def compute(listens) do
    case Card.top_tracks(listens, 5) do
      [_, second, _ | _] = top ->
        %Card{
          type: :next_tracks,
          data: %{tracks: tl(top)},
          appearance: Card.appearance(second.cover_url),
          preview: Card.preview(second.artist, second.name)
        }

      _ ->
        :skip
    end
  end
end
