defmodule PremiereEcoute.Sessions.Discography.AlbumTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.Discography.Track

  @album %Album{
    spotify_id: "album123",
    name: "Sample Album",
    artist: "Sample Artist",
    release_date: ~D[2023-01-01],
    cover_url: "http://example.com/cover.jpg",
    total_tracks: 2,
    tracks: [
      %Track{
        spotify_id: "track001",
        name: "Track One",
        track_number: 1,
        duration_ms: 210_000
      },
      %Track{
        spotify_id: "track002",
        name: "Track Two",
        track_number: 2,
        duration_ms: 180_000
      }
    ]
  }

  describe "create/1" do
    test "creates an album with tracks" do
      {:ok, album} = Album.create(@album)

      assert %Album{
               spotify_id: "album123",
               name: "Sample Album",
               artist: "Sample Artist",
               release_date: ~D[2023-01-01],
               cover_url: "http://example.com/cover.jpg",
               total_tracks: 2,
               tracks: [
                 %Track{
                   spotify_id: "track001",
                   name: "Track One",
                   track_number: 1,
                   duration_ms: 210_000
                 },
                 %Track{
                   spotify_id: "track002",
                   name: "Track Two",
                   track_number: 2,
                   duration_ms: 180_000
                 }
               ]
             } = album
    end
  end

  describe "read/1" do
    test "read an existing album" do
      {:ok, %Album{spotify_id: spotify_id}} = Album.create(@album)

      album = Album.read(spotify_id)

      assert %Album{
               spotify_id: "album123",
               name: "Sample Album",
               artist: "Sample Artist",
               release_date: ~D[2023-01-01],
               cover_url: "http://example.com/cover.jpg",
               total_tracks: 2,
               tracks: [
                 %Track{
                   spotify_id: "track001",
                   name: "Track One",
                   track_number: 1,
                   duration_ms: 210_000
                 },
                 %Track{
                   spotify_id: "track002",
                   name: "Track Two",
                   track_number: 2,
                   duration_ms: 180_000
                 }
               ]
             } = album
    end

    test "read an unexisting album" do
      assert is_nil(Album.read("unknown"))
    end
  end

  describe "delete/1" do
    test "deletes an existing album" do
      {:ok, %Album{spotify_id: spotify_id}} = Album.create(@album)

      :ok = Album.delete(spotify_id)

      assert is_nil(Album.read(spotify_id))
    end

    test "read an unexisting album" do
      spotify_id = "unknown"

      :ok = Album.delete(spotify_id)

      assert is_nil(Album.read(spotify_id))
    end
  end
end
