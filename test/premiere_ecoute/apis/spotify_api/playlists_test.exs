defmodule PremiereEcoute.Apis.SpotifyApi.PlaylistsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.SpotifyApi

  alias PremiereEcoute.Sessions.Discography.Playlist
  alias PremiereEcoute.Sessions.Discography.Playlist.Track

  @moduletag :spotify

  describe "get_playlist/1" do
    test "list playlist from an unique identifier" do
      id = "2gW4sqiC2OXZLe9m0yDQX7"

      {:ok, playlist} = SpotifyApi.get_playlist(id)

      assert %Playlist{
        spotify_id: "2gW4sqiC2OXZLe9m0yDQX7",
        spotify_owner_id: "ku296zgwbo0e3qff8cylptsjq",
        owner_name: "Flonflon",
        name: "FLONFLON MUSIC FRIDAY",
        cover_url: cover_url,
        tracks: tracks
      } = playlist

      assert Regex.match?(~r/^https:\/\/image-cdn-[a-z0-9\-]+\.spotifycdn\.com\/image\/[a-f0-9]{40}$/, cover_url)
      for track <- tracks do
        assert %Track{} = track
      end
    end
  end
end
