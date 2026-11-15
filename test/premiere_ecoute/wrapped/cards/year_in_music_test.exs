defmodule PremiereEcoute.Wrapped.Cards.YearInMusicTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Wrapped.Appearance
  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Cards.YearInMusic

  describe "compute/1" do
    test "counts the albums and their minutes" do
      listens = [album_listen(1), album_listen(2, %{streamers: ["ana", "ben"]})]

      assert %Card{type: :year_in_music, data: data} = YearInMusic.compute(listens)
      assert data == %{albums: 2, minutes: 120}
    end

    test "counts albums without score" do
      assert %Card{data: %{albums: 2}} = YearInMusic.compute([album_listen(1), album_listen(2, %{score: 9.0})])
    end

    test "counts neither singles nor tracks" do
      listens = [album_listen(1), track_listen(1, "Song", %{duration_ms: 600_000}), single_listen(1, %{duration_ms: 600_000})]

      assert %Card{data: %{albums: 1, minutes: 40}} = YearInMusic.compute(listens)
    end

    test "takes its look and its sound from the last album" do
      assert %Card{appearance: appearance, preview: preview} =
               YearInMusic.compute([album_listen(1), album_listen(2), single_listen(3)])

      assert appearance == %Appearance{cover_url: "https://i.scdn.co/image/2"}
      assert preview == %Card.Track{artist: "Artist 2", name: "Intro 2"}
    end

    test "skips without album" do
      assert YearInMusic.compute([]) == :skip
      assert YearInMusic.compute([single_listen(1), track_listen(1, "Song")]) == :skip
    end
  end
end
