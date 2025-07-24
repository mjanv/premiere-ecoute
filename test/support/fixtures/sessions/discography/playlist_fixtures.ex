defmodule PremiereEcoute.Sessions.Discography.PlaylistFixtures do
  @moduledoc false

  alias PremiereEcoute.Sessions.Discography.Playlist
  alias PremiereEcoute.Sessions.Discography.Playlist.Track

  def playlist_fixture(attrs \\ %{}) do
    %{
      spotify_id: "2gW4sqiC2OXZLe9m0yDQX7",
      name: "FLONFLON MUSIC FRIDAY",
      spotify_owner_id: "ku296zgwbo0e3qff8cylptsjq",
      owner_name: "Flonflon",
      cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
      tracks: [
        %Track{
          name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
          playlist_id: nil,
          spotify_id: "4gVsKMMK0f8dweHL7Vm9HC",
          album_spotify_id: "7eD4M0bxUGIFRCi0wWhkbt",
          user_spotify_id: "ku296zgwbo0e3qff8cylptsjq",
          artist: "Unknown Artist",
          duration_ms: 217901,
          added_at: ~N[2025-07-18 07:59:47],
        }
      ]
    }
    |> Map.merge(attrs)
    |> then(fn attrs -> struct(Playlist, attrs) end)
  end
end
