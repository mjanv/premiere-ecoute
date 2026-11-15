defmodule PremiereEcoute.Wrapped.Cards.YourRoomsTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Cards.YourRooms

  describe "compute/1" do
    test "ranks the streamers by number of sessions" do
      listens = [
        album_listen(1, %{streamers: ["ana", "ben"]}),
        album_listen(2, %{streamers: ["ana"]}),
        album_listen(3, %{streamers: ["cy", "ana"]})
      ]

      assert %Card{type: :your_rooms, data: %{rooms: rooms}} = YourRooms.compute(listens)
      assert rooms == [%{name: "ana", sessions: 3}, %{name: "ben", sessions: 1}, %{name: "cy", sessions: 1}]
    end

    test "sorts a tie by name" do
      listens = [
        album_listen(1, %{streamers: ["zoe"]}),
        album_listen(2, %{streamers: ["ana"]}),
        album_listen(3, %{streamers: ["mia"]})
      ]

      assert %Card{data: %{rooms: rooms}} = YourRooms.compute(listens)
      assert Enum.map(rooms, & &1.name) == ["ana", "mia", "zoe"]
    end

    test "keeps the first four streamers" do
      listens = [album_listen(1, %{streamers: ~w(a b c d e f)}), album_listen(2, %{streamers: ["f"]})]

      assert %Card{data: %{rooms: rooms}} = YourRooms.compute(listens)
      assert Enum.map(rooms, & &1.name) == ~w(f a b c)
    end

    test "counts the sessions of albums only" do
      listens = [
        album_listen(1, %{streamers: ["ana"]}),
        album_listen(2, %{streamers: ["ben"]}),
        single_listen(3, %{streamers: ["cy"]})
      ]

      assert %Card{data: %{rooms: rooms}} = YourRooms.compute(listens)
      assert Enum.map(rooms, & &1.name) == ["ana", "ben"]
    end

    test "takes its look and its sound from the last album" do
      listens = [album_listen(1, %{streamers: ["ana"]}), album_listen(2, %{streamers: ["ben"]})]

      assert %Card{appearance: %{cover_url: "https://i.scdn.co/image/2"}, preview: %Card.Track{name: "Intro 2"}} =
               YourRooms.compute(listens)
    end

    test "skips with a single streamer" do
      assert YourRooms.compute([album_listen(1, %{streamers: ["ana"]}), album_listen(2, %{streamers: ["ana"]})]) == :skip
      assert YourRooms.compute([]) == :skip
    end
  end
end
