defmodule PremiereEcoute.Wrapped.ListenTest do
  use ExUnit.Case, async: true

  import PremiereEcoute.Wrapped.ListenFixtures

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Wrapped.Listen

  describe "albums/1, singles/1 and tracks/1" do
    test "keep the listens of one kind, in order" do
      listens = [album_listen(1), track_listen(1, "A"), single_listen(1), album_listen(2), track_listen(2, "B"), single_listen(2)]

      assert [%Listen{entity: %Album{id: 1}}, %Listen{entity: %Album{id: 2}}] = Listen.albums(listens)
      assert [%Listen{entity: %Single{id: 1}}, %Listen{entity: %Single{id: 2}}] = Listen.singles(listens)
      assert [%Listen{entity: %Album.Track{name: "A"}}, %Listen{entity: %Album.Track{name: "B"}}] = Listen.tracks(listens)
    end

    test "return nothing for an empty list" do
      assert {Listen.albums([]), Listen.singles([]), Listen.tracks([])} == {[], [], []}
    end
  end

  describe "name/1" do
    test "reads the name of the entity" do
      assert Listen.name(album_listen(1)) == "Album 1"
      assert Listen.name(single_listen(2)) == "Single 2"
      assert Listen.name(track_listen(3, "Song")) == "Song"
    end
  end

  describe "artist/1" do
    test "names the first artist of an album or a single" do
      listen = album_listen(1, %{artists: [%Artist{name: "First"}, %Artist{name: "Second"}]})

      assert Listen.artist(listen) == "First"
      assert Listen.artist(single_listen(2)) == "Artist 2"
    end

    test "names the artist of the album of a track" do
      assert Listen.artist(track_listen(3, "Song")) == "Artist 3"
    end

    test "is nil without artist or when the album of a track is not loaded" do
      track = track_listen(1, "Song")

      assert Listen.artist(album_listen(1, %{artists: []})) == nil
      assert Listen.artist(%{track | entity: %Album.Track{name: "Song"}}) == nil
    end
  end

  describe "cover_url/1" do
    test "reads the cover of an album or a single" do
      assert Listen.cover_url(album_listen(1)) == "https://i.scdn.co/image/1"
      assert Listen.cover_url(single_listen(2, %{cover_url: nil})) == nil
    end

    test "reads the cover of the album of a track" do
      track = track_listen(3, "Song")

      assert Listen.cover_url(track) == "https://i.scdn.co/image/3"
      assert Listen.cover_url(%{track | entity: %Album.Track{name: "Song"}}) == nil
    end
  end

  describe "opening_track/1" do
    test "names the track with the lowest number of an album" do
      tracks =
        for {name, number} <- [{"Third", 3}, {"First", 1}, {"Second", 2}], do: %Album.Track{name: name, track_number: number}

      assert Listen.opening_track(album_listen(1, %{tracks: tracks})) == "First"
    end

    test "is nil for an album without tracks" do
      assert Listen.opening_track(album_listen(1, %{tracks: []})) == nil
    end

    test "names a single or a track itself" do
      assert Listen.opening_track(single_listen(2)) == "Single 2"
      assert Listen.opening_track(track_listen(3, "Song")) == "Song"
    end
  end

  describe "sessions/1" do
    test "counts one session per streamer entry, duplicates included" do
      assert Listen.sessions(album_listen(1, %{streamers: ["ana", "ana", "ben"]})) == 3
      assert Listen.sessions(album_listen(1, %{streamers: []})) == 0
    end
  end

  describe "duration_ms/1" do
    test "multiplies the duration of an album by its sessions" do
      tracks = [%Album.Track{track_number: 1, duration_ms: 210_000}, %Album.Track{track_number: 2, duration_ms: 180_000}]

      assert Listen.duration_ms(album_listen(1, %{tracks: tracks, streamers: ["ana", "ben"]})) == 780_000
    end

    test "ignores the tracks of an album without duration" do
      tracks = [%Album.Track{track_number: 1, duration_ms: 210_000}, %Album.Track{track_number: 2, duration_ms: nil}]

      assert Listen.duration_ms(album_listen(1, %{tracks: tracks})) == 210_000
    end

    test "multiplies the duration of a single or a track by its sessions" do
      assert Listen.duration_ms(single_listen(1, %{duration_ms: 200_000, streamers: ["ana", "ben"]})) == 400_000
      assert Listen.duration_ms(track_listen(1, "Song", %{duration_ms: 100_000})) == 100_000
    end

    test "is zero for a single or a track without duration" do
      assert Listen.duration_ms(single_listen(1)) == 0
      assert Listen.duration_ms(track_listen(1, "Song")) == 0
    end
  end
end
