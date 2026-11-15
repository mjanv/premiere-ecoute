defmodule PremiereEcoute.Wrapped.Cards.TopTrackTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Cards.TopTrack

  describe "compute/1" do
    test "keeps the best-rated track" do
      listens = [
        album_listen(1),
        track_listen(1, "Low", %{score: 4.0}),
        track_listen(1, "High", %{score: 9.0}),
        track_listen(2, "Higher", %{score: 10.0})
      ]

      assert %Card{type: :top_track, data: data, appearance: appearance, preview: preview} = TopTrack.compute(listens)

      assert data == %{
               track: %{name: "Higher", score: 10.0, album: "Album 2", artist: "Artist 2", cover_url: "https://i.scdn.co/image/2"}
             }

      assert appearance.cover_url == "https://i.scdn.co/image/2"
      assert preview == %Card.Track{artist: "Artist 2", name: "Higher"}
    end

    test "breaks a tie with the chat average" do
      listens = [
        track_listen(1, "Liked", %{score: 10.0, chat_score: 6.0}),
        track_listen(2, "Loved", %{score: 10.0, chat_score: 9.0})
      ]

      assert %Card{data: %{track: %{name: "Loved"}}} = TopTrack.compute(listens)
    end

    test "skips without rated track" do
      assert TopTrack.compute([album_listen(1, %{score: 9.0}), single_listen(1, %{score: 9.0})]) == :skip
      assert TopTrack.compute([]) == :skip
    end
  end
end
