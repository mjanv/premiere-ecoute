defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.ArtistsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Artist.Image
  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcouteCore.Cache

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup_all do
    token = UUID.uuid4()

    Cache.put(:tokens, :spotify, token)

    {:ok, %{token: token}}
  end

  describe "get_artist/1" do
    test "returns an artist with images", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/artists/0TnOYISbd1XYRBk9myaseg"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        response: "spotify_api/artists/get_artist/response.json",
        status: 200
      )

      {:ok, artist} = SpotifyApi.get_artist("0TnOYISbd1XYRBk9myaseg")

      assert %Artist{
               provider_ids: %{spotify: "0TnOYISbd1XYRBk9myaseg"},
               name: "Pitbull",
               images: [
                 %Image{url: "https://i.scdn.co/image/ab6761610000e5eb8d8ac7290d0fe2d12fb6e4d9", height: 640, width: 640},
                 %Image{url: "https://i.scdn.co/image/ab676161000051748d8ac7290d0fe2d12fb6e4d9", height: 320, width: 320},
                 %Image{url: "https://i.scdn.co/image/ab6761610000f1788d8ac7290d0fe2d12fb6e4d9", height: 160, width: 160}
               ]
             } = artist
    end
  end

  describe "get_artist_albums/1" do
    test "returns a list of albums for an artist", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/artists/0TnOYISbd1XYRBk9myaseg/albums"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        response: "spotify_api/artists/get_artist_albums/response.json",
        status: 200
      )

      {:ok, albums} = SpotifyApi.get_artist_albums("0TnOYISbd1XYRBk9myaseg")

      assert length(albums) == 20

      assert %{
               provider_ids: %{spotify: "1nPRTKmS3Bn0f2ih11i2aH"},
               name: "UNDERDOGS",
               artists: [%Artist{name: "IAmChino"}, %Artist{name: "Pitbull"}],
               release_date: ~D[2025-08-29],
               total_tracks: 11
             } = hd(albums)
    end
  end

  describe "get_playlist/1" do
    test "get a playlist from an unique identifier", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/artists/0TnOYISbd1XYRBk9myaseg/top-tracks"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        response: "spotify_api/artists/get_artist_top_tracks/response.json",
        status: 200
      )

      id = "0TnOYISbd1XYRBk9myaseg"

      {:ok, track} = SpotifyApi.get_artist_top_track(id)

      assert %Track{track_id: "string", name: "string"} = track
    end
  end
end
