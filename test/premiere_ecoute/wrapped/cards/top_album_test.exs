defmodule PremiereEcoute.Wrapped.Cards.TopAlbumTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Cards.TopAlbum

  describe "compute/1" do
    test "keeps the best-scored album" do
      listens = [album_listen(1, %{score: 6.0}), album_listen(2, %{score: 9.5}), album_listen(3)]

      assert %Card{type: :top_album, data: data, appearance: appearance, preview: preview} = TopAlbum.compute(listens)
      assert data == %{album: %{name: "Album 2", artist: "Artist 2", cover_url: "https://i.scdn.co/image/2", score: 9.5}}
      assert appearance.cover_url == "https://i.scdn.co/image/2"
      assert preview == %Card.Track{artist: "Artist 2", name: "Intro 2"}
    end

    test "gives a tie to the most recent vote" do
      listens = [album_listen(1, %{score: 9.0}), album_listen(3, %{score: 9.0}), album_listen(2, %{score: 9.0})]

      assert %Card{data: %{album: %{name: "Album 3"}}} = TopAlbum.compute(listens)
    end

    test "ignores singles and tracks" do
      listens = [album_listen(1, %{score: 5.0}), single_listen(2, %{score: 10.0}), track_listen(3, "Song", %{score: 10.0})]

      assert %Card{data: %{album: %{name: "Album 1"}}} = TopAlbum.compute(listens)
    end

    test "skips without scored album" do
      assert TopAlbum.compute([album_listen(1)]) == :skip
      assert TopAlbum.compute([single_listen(1, %{score: 10.0})]) == :skip
      assert TopAlbum.compute([]) == :skip
    end
  end
end
