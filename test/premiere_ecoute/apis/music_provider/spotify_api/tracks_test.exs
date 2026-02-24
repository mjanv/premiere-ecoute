defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.TracksTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcouteCore.Cache

  alias PremiereEcoute.Discography.Album.Track

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup_all do
    token = UUID.uuid4()

    Cache.put(:tokens, :spotify, token)

    {:ok, %{token: token}}
  end

  describe "get_track/1" do
    test "returns track details from a unique identifier", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/tracks/11dFghVXANMlKmJXsNCbNl"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        response: "spotify_api/albums/get_track/response.json",
        status: 200
      )

      id = "11dFghVXANMlKmJXsNCbNl"

      {:ok, track} = SpotifyApi.get_track(id)

      assert %Track{
               id: nil,
               provider: :spotify,
               track_id: "11dFghVXANMlKmJXsNCbNl",
               album_id: "0tGPJ0bkWOUmH7MEOR77qc",
               name: "Cut To The Feeling",
               track_number: 1,
               duration_ms: 207_959
             } = track
    end
  end
end
