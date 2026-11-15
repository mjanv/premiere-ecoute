defmodule PremiereEcoute.Wrapped.SamplesTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.Wrapped.WrappedFixtures

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcoute.Wrapped.Listen
  alias PremiereEcoute.Wrapped.Samples

  describe "listens/1" do
    test "returns nothing without album" do
      assert Samples.listens() == []
    end

    test "builds an album listen for each of the latest albums with a cover" do
      for n <- 1..4, do: album_record(n)
      album_record(5, %{cover_url: nil})

      assert Samples.listens() |> Listen.albums() |> Enum.map(&Listen.name/1) == ["Album 1", "Album 2", "Album 3", "Album 4"]
    end

    test "looks at the latest albums only" do
      for n <- 1..4, do: album_record(n)

      assert Samples.listens(2) |> Listen.albums() |> length() == 2
    end

    test "spreads the albums over time, the last one 20 days ago" do
      for n <- 1..3, do: album_record(n)

      dates = Samples.listens() |> Listen.albums() |> Enum.map(& &1.result.voted_at)

      assert dates == Enum.sort(dates, DateTime)
      assert_in_delta DateTime.diff(DateTime.utc_now(), List.last(dates), :day), 20, 1
      assert_in_delta DateTime.diff(List.last(dates), hd(dates), :day), 40, 1
    end

    test "invents scores, chat scores and streamers" do
      for n <- 1..2, do: album_record(n)

      assert [%{result: one}, %{result: two}] = Samples.listens() |> Listen.albums()
      assert {one.score, one.chat_score, one.streamers} == {7.5, 7.2, ["ana"]}
      assert {two.score, two.chat_score, two.streamers} == {9.0, 6.1, ["ben"]}
    end

    test "rates the first tracks of each album, never above 10" do
      album_record(1)
      album_record(2)

      tracks = Samples.listens() |> Listen.tracks()

      assert Enum.map(tracks, &{&1.entity.album.name, Listen.name(&1), &1.result.score}) == [
               {"Album 1", "Track One", 7.5},
               {"Album 1", "Track Two", 8.5},
               {"Album 2", "Track One", 9.0},
               {"Album 2", "Track Two", 10.0}
             ]
    end

    test "makes singles out of the opening track of the first albums" do
      for n <- 1..4, do: album_record(n)

      singles = Samples.listens() |> Listen.singles()

      assert length(singles) == 3

      assert [
               %Listen{entity: %Single{name: "Track One", cover_url: "http://example.com/cover.jpg"}, result: %{score: 7.5}} =
                 single
               | _
             ] = singles

      assert {Listen.artist(single), Listen.duration_ms(single)} == {"Sample Artist", 0}
    end

    test "writes nothing" do
      album_record(1)

      Samples.listens()

      assert {Repo.aggregate(Album, :count), Repo.aggregate(Single, :count), Repo.aggregate(Vote, :count)} == {1, 0, 0}
    end
  end
end
