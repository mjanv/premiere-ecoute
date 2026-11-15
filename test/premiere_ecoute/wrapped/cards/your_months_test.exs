defmodule PremiereEcoute.Wrapped.Cards.YourMonthsTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Cards.YourMonths

  describe "compute/1" do
    test "counts the albums of each month and names the busiest one" do
      listens = [album_listen(2), album_listen(5), album_listen(6, %{voted_at: at(5, 20)}), album_listen(11)]

      assert %Card{type: :your_months, data: data, appearance: appearance, preview: preview} = YourMonths.compute(listens)
      assert data == %{months: [0, 1, 0, 0, 2, 0, 0, 0, 0, 0, 1, 0], busiest: 5}
      assert appearance.cover_url == "https://i.scdn.co/image/5"
      assert preview == %Card.Track{artist: "Artist 5", name: "Intro 5"}
    end

    test "places January first and December last" do
      assert %Card{data: %{months: months}} = YourMonths.compute([album_listen(1), album_listen(12)])
      assert months == [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    end

    test "gives a tie to the earliest month" do
      listens = [album_listen(3), album_listen(4, %{voted_at: at(3, 9)}), album_listen(8), album_listen(9, %{voted_at: at(8, 9)})]

      assert %Card{data: %{busiest: 3}, appearance: %{cover_url: "https://i.scdn.co/image/3"}} = YourMonths.compute(listens)
    end

    test "counts neither singles nor tracks" do
      listens = [
        album_listen(1),
        album_listen(2),
        single_listen(2),
        single_listen(3, %{voted_at: at(2, 5)}),
        track_listen(2, "Song")
      ]

      assert %Card{data: %{months: [1, 1 | _], busiest: 1}} = YourMonths.compute(listens)
    end

    test "skips when every album falls in the same month" do
      assert YourMonths.compute([album_listen(3), album_listen(4, %{voted_at: at(3, 9)})]) == :skip
      assert YourMonths.compute([]) == :skip
    end
  end
end
