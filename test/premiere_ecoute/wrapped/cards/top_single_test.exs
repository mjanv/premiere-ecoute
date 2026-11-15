defmodule PremiereEcoute.Wrapped.Cards.TopSingleTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Cards.TopSingle

  describe "compute/1" do
    test "keeps the best-scored single" do
      listens = [single_listen(1, %{score: 6.0}), single_listen(2, %{score: 9.0}), single_listen(3)]

      assert %Card{type: :top_single, data: data, appearance: appearance, preview: preview} = TopSingle.compute(listens)
      assert data == %{single: %{name: "Single 2", artist: "Artist 2", cover_url: "https://i.scdn.co/image/2", score: 9.0}}
      assert appearance.cover_url == "https://i.scdn.co/image/2"
      assert preview == %Card.Track{artist: "Artist 2", name: "Single 2"}
    end

    test "gives a tie to the most recent vote" do
      assert %Card{data: %{single: %{name: "Single 3"}}} =
               TopSingle.compute([single_listen(3, %{score: 9.0}), single_listen(1, %{score: 9.0})])
    end

    test "ignores albums and tracks" do
      listens = [album_listen(1, %{score: 10.0}), track_listen(1, "Song", %{score: 10.0}), single_listen(2, %{score: 3.0})]

      assert %Card{data: %{single: %{name: "Single 2"}}} = TopSingle.compute(listens)
    end

    test "skips without scored single" do
      assert TopSingle.compute([]) == :skip
      assert TopSingle.compute([single_listen(1)]) == :skip
      assert TopSingle.compute([album_listen(1, %{score: 10.0})]) == :skip
    end
  end
end
