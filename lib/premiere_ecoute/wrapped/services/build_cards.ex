defmodule PremiereEcoute.Wrapped.Services.BuildCards do
  @moduledoc """
  Builds the cards of a Wrapped from what a viewer voted on.

  Each card module decides whether it has enough to show; a viewer below the minimum number of albums gets no card at all.
  """

  alias PremiereEcoute.Wrapped.Appearance
  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Cards
  alias PremiereEcoute.Wrapped.Listen
  alias PremiereEcoute.Wrapped.Samples

  # Play order. When this list changes, bump `PremiereEcoute.Wrapped.Recap.version/0`.
  @cards [
    Cards.YearInMusic,
    Cards.CoverWall,
    Cards.YourRooms,
    Cards.YourMonths,
    Cards.FirstVote,
    Cards.TopAlbum,
    Cards.NextAlbums,
    Cards.TopTrack,
    Cards.NextTracks,
    Cards.TopSingle,
    Cards.YouAndChat,
    Cards.Recap
  ]

  @doc "Builds the cards of a viewer's listens, skipping the cards with too little data."
  @spec cards([Listen.t()]) :: [Card.t()]
  def cards(listens) do
    if length(Listen.albums(listens)) >= min_albums() do
      cards = @cards |> Enum.map(& &1.compute(listens)) |> Enum.reject(&(&1 == :skip))

      # Several cards share a cover: each one is fetched once
      colors = cards |> Enum.map(& &1.appearance.cover_url) |> Enum.uniq() |> Map.new(&{&1, Appearance.extract(&1)})

      Enum.map(cards, fn card -> put_in(card.appearance.colors, colors[card.appearance.cover_url]) end)
    else
      []
    end
  end

  @doc """
  Builds sample cards, as stored (string keys), from the latest albums of the discography, with made-up scores.

  Read-only: nothing is stored. Used to preview the page without real votes.
  """
  @spec demo_cards() :: [map()]
  def demo_cards do
    Samples.listens() |> cards() |> Jason.encode!() |> Jason.decode!()
  end

  defp min_albums, do: Application.get_env(:premiere_ecoute, PremiereEcoute.Wrapped, [])[:min_albums] || 3
end
