defmodule PremiereEcoute.Discography.PlaylistFixtures do
  @moduledoc """
  Playlist fixutres

  Provides factory functions to generate test playlist structs with associated tracks for use in test suites.
  """

  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track

  def playlist_fixture(attrs \\ %{}) do
    %{
      provider: :spotify,
      playlist_id: "2gW4sqiC2OXZLe9m0yDQX7",
      title: "FLONFLON MUSIC FRIDAY",
      owner_id: "ku296zgwbo0e3qff8cylptsjq",
      owner_name: "Flonflon",
      url: "https://open.spotify.com/playlist/2gW4sqiC2OXZLe9m0yDQX7",
      cover_url: "https://image-cdn-fa.spotifycdn.com/image/ab67706c0000da84a23ec98e47645b74cd76e3fd",
      tracks: [
        %Track{
          provider: :spotify,
          name: "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)",
          playlist_id: nil,
          track_id: "4gVsKMMK0f8dweHL7Vm9HC",
          album_id: "7eD4M0bxUGIFRCi0wWhkbt",
          user_id: "ku296zgwbo0e3qff8cylptsjq",
          artist: "Unknown Artist",
          duration_ms: 217_901,
          added_at: ~N[2025-07-18 07:59:47],
          release_date: ~D[2025-07-17]
        }
      ]
    }
    |> Map.merge(attrs)
    |> then(fn attrs -> struct(Playlist, attrs) end)
  end
end
