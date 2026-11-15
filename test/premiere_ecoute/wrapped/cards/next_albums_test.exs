defmodule PremiereEcoute.Wrapped.Cards.NextAlbumsTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Cards.NextAlbums

  describe "compute/1" do
    test "keeps the albums ranked 2 to 5" do
      listens = for n <- 1..7, do: album_listen(n, %{score: n * 1.0})

      assert %Card{type: :next_albums, data: %{albums: albums}} = NextAlbums.compute(listens)
      assert Enum.map(albums, &{&1.name, &1.score}) == [{"Album 6", 6.0}, {"Album 5", 5.0}, {"Album 4", 4.0}, {"Album 3", 3.0}]
    end

    test "takes its look and its sound from the second album" do
      listens = for n <- 1..3, do: album_listen(n, %{score: n * 1.0})

      assert %Card{appearance: %{cover_url: "https://i.scdn.co/image/2"}, preview: %Card.Track{name: "Intro 2"}} =
               NextAlbums.compute(listens)
    end

    test "shows two albums with three scored albums" do
      listens = [album_listen(1, %{score: 6.0}), album_listen(2, %{score: 7.0}), album_listen(3, %{score: 8.0}), album_listen(4)]

      assert %Card{data: %{albums: [%{name: "Album 2"}, %{name: "Album 1"}]}} = NextAlbums.compute(listens)
    end

    test "ignores singles" do
      listens = [album_listen(1, %{score: 6.0}), album_listen(2, %{score: 7.0}), single_listen(3, %{score: 8.0})]

      assert NextAlbums.compute(listens) == :skip
    end

    test "skips with fewer than 3 scored albums" do
      assert NextAlbums.compute([album_listen(1, %{score: 6.0}), album_listen(2, %{score: 7.0}), album_listen(3)]) == :skip
      assert NextAlbums.compute([]) == :skip
    end
  end
end
