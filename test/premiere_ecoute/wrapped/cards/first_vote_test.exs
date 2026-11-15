defmodule PremiereEcoute.Wrapped.Cards.FirstVoteTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Cards.FirstVote

  describe "compute/1" do
    test "keeps the first album and the day of its first vote" do
      assert %Card{type: :first_vote, data: data, appearance: appearance, preview: preview} =
               FirstVote.compute([album_listen(2), album_listen(4)])

      assert data == %{album: %{name: "Album 2", artist: "Artist 2", cover_url: "https://i.scdn.co/image/2"}, date: "2026-02-01"}
      assert appearance.cover_url == "https://i.scdn.co/image/2"
      assert preview == %Card.Track{artist: "Artist 2", name: "Intro 2"}
    end

    test "gives the day in UTC" do
      late = album_listen(3, %{voted_at: ~U[2026-03-31 23:30:00Z]})

      assert %Card{data: %{date: "2026-03-31"}} = FirstVote.compute([late])
    end

    test "starts from the first album, even after a single" do
      assert %Card{data: %{album: %{name: "Album 4"}}} =
               FirstVote.compute([single_listen(1), track_listen(4, "Song"), album_listen(4)])
    end

    test "skips without album" do
      assert FirstVote.compute([]) == :skip
      assert FirstVote.compute([single_listen(1)]) == :skip
    end
  end
end
