defmodule PremiereEcoute.Wrapped.Cards.NextTracksTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Cards.NextTracks

  describe "compute/1" do
    test "keeps one track per album, ranked 2 to 5" do
      listens = [
        track_listen(1, "A1", %{score: 10.0, chat_score: 5.0}),
        track_listen(1, "A2", %{score: 10.0, chat_score: 8.0}),
        track_listen(2, "B1", %{score: 10.0, chat_score: 9.0}),
        track_listen(3, "C1", %{score: 9.0}),
        track_listen(3, "C2", %{score: 3.0}),
        track_listen(4, "D1", %{score: 7.0})
      ]

      assert %Card{type: :next_tracks, data: %{tracks: tracks}} = NextTracks.compute(listens)
      assert Enum.map(tracks, &{&1.name, &1.album}) == [{"A2", "Album 1"}, {"C1", "Album 3"}, {"D1", "Album 4"}]
    end

    test "takes its look and its sound from the second track" do
      listens = for n <- 1..3, do: track_listen(n, "T#{n}", %{score: n * 1.0})

      assert %Card{appearance: appearance, preview: preview} = NextTracks.compute(listens)
      assert appearance.cover_url == "https://i.scdn.co/image/2"
      assert preview == %Card.Track{artist: "Artist 2", name: "T2"}
    end

    test "shows two tracks with three albums and four with more than five" do
      three = for n <- 1..3, do: track_listen(n, "T#{n}", %{score: n * 1.0})
      eight = for n <- 1..8, do: track_listen(n, "T#{n}", %{score: n * 1.0})

      assert %Card{data: %{tracks: [%{name: "T2"}, %{name: "T1"}]}} = NextTracks.compute(three)
      assert %Card{data: %{tracks: tracks}} = NextTracks.compute(eight)
      assert Enum.map(tracks, & &1.name) == ~w(T7 T6 T5 T4)
    end

    test "skips with fewer than 3 albums with rated tracks" do
      listens = [
        track_listen(1, "A1", %{score: 10.0}),
        track_listen(1, "A2", %{score: 9.0}),
        track_listen(1, "A3", %{score: 8.0}),
        track_listen(2, "B1", %{score: 8.0})
      ]

      assert NextTracks.compute(listens) == :skip
      assert NextTracks.compute([]) == :skip
    end
  end
end
