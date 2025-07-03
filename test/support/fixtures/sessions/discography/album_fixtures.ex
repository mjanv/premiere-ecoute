defmodule PremiereEcoute.Sessions.Discography.AlbumFixtures do
  @moduledoc false

  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.Discography.Track

  def album_fixture do
    %Album{
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
  end
end
