defmodule PremiereEcoute.Wrapped.Cards.CoverWallTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Cards.CoverWall

  describe "compute/1" do
    test "lists the covers of the albums in order" do
      listens = [album_listen(1), single_listen(9), album_listen(2), track_listen(2, "Song"), album_listen(3), album_listen(4)]

      assert %Card{type: :cover_wall, data: %{covers: covers}} = CoverWall.compute(listens)
      assert Enum.map(covers, & &1.name) == ["Album 1", "Album 2", "Album 3", "Album 4"]
      assert hd(covers) == %{name: "Album 1", artist: "Artist 1", cover_url: "https://i.scdn.co/image/1"}
    end

    test "leaves out albums without cover" do
      listens = [album_listen(1, %{cover_url: nil}) | Enum.map(2..5, &album_listen/1)]

      assert %Card{data: %{covers: covers}, appearance: appearance} = CoverWall.compute(listens)
      assert Enum.map(covers, & &1.name) == ["Album 2", "Album 3", "Album 4", "Album 5"]
      assert appearance.cover_url == "https://i.scdn.co/image/2"
    end

    test "plays no sound" do
      assert %Card{preview: nil} = CoverWall.compute(Enum.map(1..4, &album_listen/1))
    end

    test "skips with fewer than 4 covers" do
      assert CoverWall.compute(Enum.map(1..3, &album_listen/1)) == :skip
      assert CoverWall.compute([album_listen(4, %{cover_url: nil}) | Enum.map(1..3, &album_listen/1)]) == :skip
      assert %Card{} = CoverWall.compute(Enum.map(1..4, &album_listen/1))
    end
  end
end
