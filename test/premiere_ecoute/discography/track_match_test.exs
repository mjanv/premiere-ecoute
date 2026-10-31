defmodule PremiereEcoute.Discography.TrackMatchTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Discography.TrackMatch

  defp candidate(attrs) do
    Map.merge(
      %{id: "abc", title: "Song", artists: ["Artist"], album: "Album", track_number: 4, duration_ms: 253_000},
      attrs
    )
  end

  defp wanted(attrs \\ %{}) do
    Map.merge(%{title: "Song", artist: "Artist", album: "Album", track_number: 4, length_ms: 253_000}, attrs)
  end

  describe "pick/2" do
    test "picks the candidate that matches the title, the artist and the length" do
      assert {:ok, "abc"} = TrackMatch.pick([candidate(%{})], wanted())
    end

    test "ignores case, accents and spacing" do
      assert {:ok, "abc"} =
               TrackMatch.pick(
                 [candidate(%{title: "  Shoot'n  Up ", artists: ["Méshell"]})],
                 wanted(%{title: "shoot'n up", artist: "MESHELL"})
               )
    end

    test "finds the artist inside a joined artist line" do
      candidates = [candidate(%{artists: ["Sampha"]})]

      assert {:ok, "abc"} = TrackMatch.pick(candidates, wanted(%{artist: "Sampha, The Avalanches"}))
      assert {:ok, "abc"} = TrackMatch.pick(candidates, wanted(%{artist: "The Avalanches; Sampha"}))
    end

    test "refuses another artist: a cover is not the track" do
      assert :error = TrackMatch.pick([candidate(%{artists: ["Someone Else"]})], wanted())
    end

    test "tolerates 3 seconds of difference in length, no more" do
      assert {:ok, "abc"} = TrackMatch.pick([candidate(%{duration_ms: 255_900})], wanted())
      assert :error = TrackMatch.pick([candidate(%{duration_ms: 257_100})], wanted())
    end

    test "does not use a length that one side does not know" do
      assert {:ok, "abc"} = TrackMatch.pick([candidate(%{duration_ms: nil})], wanted())
      assert {:ok, "abc"} = TrackMatch.pick([candidate(%{})], wanted(%{length_ms: 0}))
    end

    test "prefers the album and the track number when the same song exists twice" do
      candidates = [
        candidate(%{id: "compilation", album: "Greatest Hits", track_number: 12}),
        candidate(%{id: "original"})
      ]

      assert {:ok, "original"} = TrackMatch.pick(candidates, wanted())
    end

    test "falls back to the album alone when the track number is not reported" do
      candidates = [
        candidate(%{id: "compilation", album: "Greatest Hits", track_number: 12}),
        candidate(%{id: "original"})
      ]

      assert {:ok, "original"} = TrackMatch.pick(candidates, wanted(%{track_number: nil}))
    end

    test "gives the same answer whatever the order of equal candidates" do
      a = candidate(%{id: "a", album: "X"})
      b = candidate(%{id: "b", album: "Y"})

      assert TrackMatch.pick([a, b], wanted(%{album: "Z"})) == TrackMatch.pick([b, a], wanted(%{album: "Z"}))
    end

    test "skips a candidate without a Spotify id and answers :error when nothing fits" do
      assert :error = TrackMatch.pick([candidate(%{id: nil})], wanted())
      assert :error = TrackMatch.pick([], wanted())
    end

    test "never matches a track whose title is empty" do
      assert :error = TrackMatch.pick([candidate(%{title: ""})], wanted(%{title: ""}))
    end
  end

  describe "find/1" do
    test "finds an album track" do
      {:ok, _} =
        Album.create(%Album{
          provider_ids: %{spotify: "alb1"},
          name: "Plantation Lullabies",
          artists: [%Artist{name: "Meshell Ndegeocello"}],
          release_date: ~D[1993-01-01],
          total_tracks: 2,
          tracks: [
            %Track{provider_ids: %{spotify: "t3"}, name: "Other", track_number: 3, duration_ms: 200_000},
            %Track{provider_ids: %{spotify: "t4"}, name: "Shoot'n up and Gett'n High", track_number: 4, duration_ms: 253_000}
          ]
        })

      assert {:ok, "t4"} =
               TrackMatch.find(%{
                 title: "Shoot'n up and Gett'n High",
                 artist: "Meshell Ndegeocello",
                 album: "Plantation Lullabies",
                 track_number: 4,
                 length_ms: 253_000
               })
    end

    test "finds a single" do
      {:ok, artist} = Artist.create_if_not_exists(%{name: "Single Artist"})

      {:ok, _} =
        Single.create(%Single{provider_ids: %{spotify: "s1"}, name: "Lonely", artists: [artist], duration_ms: 180_000})

      assert {:ok, "s1"} =
               TrackMatch.find(%{
                 title: "lonely",
                 artist: "Single Artist",
                 album: "Lonely",
                 track_number: nil,
                 length_ms: 181_000
               })
    end

    test "answers :error for a track nobody stored" do
      assert :error = TrackMatch.find(%{title: "Unknown", artist: "Nobody", album: "", track_number: nil, length_ms: 1000})
    end
  end
end
