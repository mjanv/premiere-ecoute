defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.ArtistsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Discography.Playlist.Track
  alias PremiereEcouteCore.Cache

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup_all do
    token = UUID.uuid4()

    Cache.put(:tokens, :spotify, token)

    {:ok, %{token: token}}
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
