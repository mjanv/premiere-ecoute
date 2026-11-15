defmodule PremiereEcoute.Wrapped.Cards.YearInMusic do
  @moduledoc """
  Your year in music: albums voted on and minutes of music listened in sessions.
  """

  @behaviour PremiereEcoute.Wrapped.Card

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Listen

  @impl true
  def compute(listens) do
    case Listen.albums(listens) do
      [] -> :skip
      albums -> card(albums)
    end
  end

  defp card(albums) do
    latest = List.last(albums)

    %Card{
      type: :year_in_music,
      data: %{albums: length(albums), minutes: Card.minutes(albums)},
      appearance: Card.appearance(latest),
      preview: Card.preview(latest)
    }
  end
end
