defmodule PremiereEcoute.Wrapped.Cards.RecapTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Cards.Recap

  describe "compute/1" do
    test "gathers the top 3, the album count and the minutes" do
      listens = [album_listen(1, %{score: 6.0}), album_listen(2, %{score: 9.5}), album_listen(3, %{score: 8.0}), album_listen(4)]

      assert %Card{type: :recap, data: data, appearance: appearance, preview: preview} = Recap.compute(listens)
      assert Enum.map(data.top, &{&1.name, &1.score}) == [{"Album 2", 9.5}, {"Album 3", 8.0}, {"Album 1", 6.0}]
      assert {data.albums, data.minutes} == {4, 160}
      assert appearance.cover_url == "https://i.scdn.co/image/2"
      assert preview == %Card.Track{artist: "Artist 2", name: "Intro 2"}
    end

    test "leaves a fourth scored album out of the top" do
      listens = for n <- 1..4, do: album_listen(n, %{score: n * 1.0})

      assert %Card{data: %{top: top, albums: 4}} = Recap.compute(listens)
      assert Enum.map(top, & &1.name) == ["Album 4", "Album 3", "Album 2"]
    end

    test "counts neither singles nor tracks" do
      listens = [single_listen(9, %{score: 10.0, duration_ms: 600_000}) | for(n <- 1..3, do: album_listen(n, %{score: n * 1.0}))]

      assert %Card{data: %{top: [%{name: "Album 3"} | _], albums: 3, minutes: 120}} = Recap.compute(listens)
    end

    test "skips with fewer than 3 scored albums" do
      assert Recap.compute([album_listen(1, %{score: 6.0}), album_listen(2, %{score: 7.0}), album_listen(3)]) == :skip
      assert Recap.compute([]) == :skip
    end
  end
end
