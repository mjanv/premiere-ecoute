defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.TracksTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcouteCore.Cache

  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Single

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup_all do
    token = UUID.uuid4()

    Cache.put(:tokens, :spotify, token)

    {:ok, %{token: token}}
  end

  describe "get_single/1" do
    test "returns single details from a unique identifier", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/tracks/11dFghVXANMlKmJXsNCbNl"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        response: "spotify_api/tracks/get_single/response.json",
        status: 200
      )

      {:ok, single} = SpotifyApi.get_single("11dFghVXANMlKmJXsNCbNl")

      assert %Single{
               id: nil,
               provider: :spotify,
               track_id: "11dFghVXANMlKmJXsNCbNl",
               name: "Cut To The Feeling",
               artist: "Carly Rae Jepsen",
               duration_ms: 207_959,
               cover_url: "https://i.scdn.co/image/ab67616d00001e027359994525d219f64872d3b1"
             } = single
    end
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
