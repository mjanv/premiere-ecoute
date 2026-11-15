defmodule PremiereEcoute.Wrapped.CardTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Wrapped.Appearance
  alias PremiereEcoute.Wrapped.Card
  alias PremiereEcoute.Wrapped.Card.Track
  alias PremiereEcoute.Wrapped.Listen

  describe "struct" do
    test "requires a type and an appearance" do
      assert_raise ArgumentError, fn -> struct!(Card, type: :recap) end
      assert_raise ArgumentError, fn -> struct!(Card, appearance: %Appearance{}) end
      assert %Card{preview: nil, data: %{}} = struct!(Card, type: :recap, appearance: %Appearance{})
    end

    test "requires a name and an artist for a track" do
      assert_raise ArgumentError, fn -> struct!(Track, name: "Song") end
    end

    test "encodes to JSON with a string type and nested appearance and preview" do
      card = %Card{
        type: :top_album,
        appearance: %Appearance{cover_url: "https://cover", colors: ["#ffffff"]},
        preview: %Track{artist: "Artist", name: "Song"},
        data: %{album: %{name: "Album", score: 9.5}}
      }

      assert card |> Jason.encode!() |> Jason.decode!() == %{
               "type" => "top_album",
               "appearance" => %{"cover_url" => "https://cover", "colors" => ["#ffffff"]},
               "preview" => %{"artist" => "Artist", "name" => "Song"},
               "data" => %{"album" => %{"name" => "Album", "score" => 9.5}}
             }
    end

    test "encodes a missing preview as null" do
      card = %Card{type: :cover_wall, appearance: %Appearance{}}

      assert %{"preview" => nil, "appearance" => %{"cover_url" => nil, "colors" => []}, "data" => %{}} =
               card |> Jason.encode!() |> Jason.decode!()
    end
  end

  describe "appearance/1" do
    test "takes the cover of a listen, without colours yet" do
      assert Card.appearance(album_listen(1)) == %Appearance{cover_url: "https://i.scdn.co/image/1", colors: []}
      assert Card.appearance(track_listen(2, "Song")) == %Appearance{cover_url: "https://i.scdn.co/image/2", colors: []}
    end

    test "wraps a cover URL or its absence" do
      assert Card.appearance("https://cover") == %Appearance{cover_url: "https://cover", colors: []}
      assert Card.appearance(nil) == %Appearance{cover_url: nil, colors: []}
    end
  end

  describe "album/1 and scored/1" do
    test "keep the name, the artist and the cover" do
      assert Card.album(album_listen(1, %{score: 8.0})) == %{
               name: "Album 1",
               artist: "Artist 1",
               cover_url: "https://i.scdn.co/image/1"
             }

      assert Card.album(single_listen(2)) == %{name: "Single 2", artist: "Artist 2", cover_url: "https://i.scdn.co/image/2"}
    end

    test "add the viewer's score" do
      assert Card.scored(album_listen(1, %{score: 8.0})) ==
               %{name: "Album 1", artist: "Artist 1", cover_url: "https://i.scdn.co/image/1", score: 8.0}

      assert %{score: nil} = Card.scored(album_listen(1))
    end
  end

  describe "preview/1 and preview/2" do
    test "name the opening track of a listen" do
      assert Card.preview(album_listen(1)) == %Track{artist: "Artist 1", name: "Intro 1"}
      assert Card.preview(single_listen(2)) == %Track{artist: "Artist 2", name: "Single 2"}
      assert Card.preview(track_listen(3, "Song")) == %Track{artist: "Artist 3", name: "Song"}
    end

    test "are nil without artist or without track" do
      assert Card.preview(album_listen(1, %{tracks: []})) == nil
      assert Card.preview(album_listen(1, %{artists: []})) == nil
      assert Card.preview(nil, "Song") == nil
      assert Card.preview("Artist", nil) == nil
    end

    test "name a given artist and track" do
      assert Card.preview("Artist", "Song") == %Track{artist: "Artist", name: "Song"}
    end
  end

  describe "minutes/1" do
    test "sums the durations, then rounds down once" do
      half = fn n ->
        album_listen(n, %{tracks: [%PremiereEcoute.Discography.Album.Track{track_number: 1, duration_ms: 30_000}]})
      end

      assert Card.minutes([half.(1)]) == 0
      assert Card.minutes([half.(1), half.(2)]) == 1
      assert Card.minutes([album_listen(1), album_listen(2, %{streamers: ["ana", "ben"]})]) == 120
      assert Card.minutes([]) == 0
    end
  end

  describe "top/2" do
    test "ranks by score, best first, three by default" do
      listens = for n <- 1..5, do: album_listen(n, %{score: n * 1.0})

      assert listens |> Card.top() |> Enum.map(&Listen.name/1) == ["Album 5", "Album 4", "Album 3"]
      assert listens |> Card.top(1) |> Enum.map(&Listen.name/1) == ["Album 5"]
      assert listens |> Card.top(10) |> length() == 5
    end

    test "leaves out unscored listens and keeps a score of zero" do
      listens = [album_listen(1), album_listen(2, %{score: 0.0}), album_listen(3, %{score: 4.0})]

      assert listens |> Card.top() |> Enum.map(&Listen.name/1) == ["Album 3", "Album 2"]
    end

    test "gives a tie to the most recent vote" do
      listens = [album_listen(1, %{score: 8.0}), album_listen(3, %{score: 8.0}), album_listen(2, %{score: 8.0})]

      assert listens |> Card.top() |> Enum.map(&Listen.name/1) == ["Album 3", "Album 2", "Album 1"]
    end
  end

  describe "top_tracks/2" do
    test "ranks tracks by score and describes them with their album" do
      listens = [album_listen(1), track_listen(1, "Low", %{score: 4.0}), track_listen(2, "High", %{score: 9.0})]

      assert Card.top_tracks(listens, 5) == [
               %{name: "High", score: 9.0, album: "Album 2", artist: "Artist 2", cover_url: "https://i.scdn.co/image/2"},
               %{name: "Low", score: 4.0, album: "Album 1", artist: "Artist 1", cover_url: "https://i.scdn.co/image/1"}
             ]
    end

    test "keeps one track per album: its best-rated one" do
      listens = [
        track_listen(1, "A1", %{score: 6.0}),
        track_listen(1, "A2", %{score: 9.0}),
        track_listen(2, "B1", %{score: 7.0}),
        track_listen(1, "A3", %{score: 8.0})
      ]

      assert listens |> Card.top_tracks(5) |> Enum.map(& &1.name) == ["A2", "B1"]
    end

    test "breaks a tie inside an album with the chat average, then the latest vote" do
      by_chat = [
        track_listen(1, "Liked", %{score: 10.0, chat_score: 6.0}),
        track_listen(1, "Loved", %{score: 10.0, chat_score: 9.0})
      ]

      by_date = [
        track_listen(1, "Later", %{score: 10.0, voted_at: at(1, 9)}),
        track_listen(1, "Earlier", %{score: 10.0, voted_at: at(1, 2)})
      ]

      assert [%{name: "Loved"}] = Card.top_tracks(by_chat, 5)
      assert [%{name: "Later"}] = Card.top_tracks(by_date, 5)
    end

    test "breaks a tie between albums with the chat average, then the latest vote" do
      listens = [
        track_listen(1, "Old and unknown", %{score: 10.0}),
        track_listen(2, "Loved", %{score: 10.0, chat_score: 9.0}),
        track_listen(3, "Liked", %{score: 10.0, chat_score: 6.0}),
        track_listen(4, "Recent and unknown", %{score: 10.0})
      ]

      assert listens |> Card.top_tracks(5) |> Enum.map(& &1.name) == ["Loved", "Liked", "Recent and unknown", "Old and unknown"]
    end

    test "ranks a missing chat average like a chat average of zero" do
      listens = [
        track_listen(1, "Unknown", %{score: 10.0, voted_at: at(1, 9)}),
        track_listen(2, "Zero", %{score: 10.0, chat_score: 0.0, voted_at: at(1, 2)})
      ]

      assert listens |> Card.top_tracks(5) |> Enum.map(& &1.name) == ["Unknown", "Zero"]
    end

    test "honours the count and ignores albums and singles" do
      listens = [
        album_listen(1, %{score: 10.0}),
        single_listen(1, %{score: 10.0}) | for(n <- 1..6, do: track_listen(n, "T#{n}", %{score: n * 1.0}))
      ]

      assert listens |> Card.top_tracks(2) |> Enum.map(& &1.name) == ["T6", "T5"]
      assert Card.top_tracks([album_listen(1, %{score: 10.0})], 5) == []
    end
  end
end
