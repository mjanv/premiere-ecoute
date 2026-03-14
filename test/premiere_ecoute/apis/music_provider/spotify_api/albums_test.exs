defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.AlbumsTest do
  use PremiereEcoute.DataCase

  import ExUnit.CaptureLog

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcouteCore.Cache

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Artist

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup_all do
    token = UUID.uuid4()

    Cache.put(:tokens, :spotify, token)

    {:ok, %{token: token}}
  end

  describe "get_album/1" do
    test "list album and track details from an unique identifier", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/albums/7aJuG4TFXa2hmE4z1yxc3n"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        response: "spotify_api/albums/get_album/response.json",
        status: 200
      )

      id = "7aJuG4TFXa2hmE4z1yxc3n"

      {:ok, album} = SpotifyApi.get_album(id)

      assert %Album{
               id: nil,
               provider_ids: %{spotify: "7aJuG4TFXa2hmE4z1yxc3n"},
               name: "HIT ME HARD AND SOFT",
               artist: nil,
               artists: [%Artist{name: "Billie Eilish"}],
               release_date: ~D[2024-05-17],
               cover_url: "https://i.scdn.co/image/ab67616d00001e0271d62ea7ea8a5be92d3c1f62",
               total_tracks: 10,
               tracks: [
                 %Track{
                   id: nil,
                   provider_ids: %{spotify: "1CsMKhwEmNnmvHUuO5nryA"},
                   name: "SKINNY",
                   track_number: 1,
                   duration_ms: 219_733
                 },
                 %Track{
                   id: nil,
                   provider_ids: %{spotify: "629DixmZGHc7ILtEntuiWE"},
                   name: "LUNCH",
                   track_number: 2,
                   duration_ms: 179_586
                 },
                 %Track{
                   id: nil,
                   provider_ids: %{spotify: "7BRD7x5pt8Lqa1eGYC4dzj"},
                   name: "CHIHIRO",
                   track_number: 3,
                   duration_ms: 303_440
                 },
                 %Track{
                   id: nil,
                   provider_ids: %{spotify: "6dOtVTDdiauQNBQEDOtlAB"},
                   name: "BIRDS OF A FEATHER",
                   track_number: 4,
                   duration_ms: 210_373
                 },
                 %Track{
                   id: nil,
                   provider_ids: %{spotify: "3QaPy1KgI7nu9FJEQUgn6h"},
                   name: "WILDFLOWER",
                   track_number: 5,
                   duration_ms: 261_466
                 },
                 %Track{
                   id: nil,
                   provider_ids: %{spotify: "6TGd66r0nlPaYm3KIoI7ET"},
                   name: "THE GREATEST",
                   track_number: 6,
                   duration_ms: 293_840
                 },
                 %Track{
                   id: nil,
                   provider_ids: %{spotify: "6fPan2saHdFaIHuTSatORv"},
                   name: "L’AMOUR DE MA VIE",
                   track_number: 7,
                   duration_ms: 333_986
                 },
                 %Track{
                   id: nil,
                   provider_ids: %{spotify: "1LLUoftvmTjVNBHZoQyveF"},
                   name: "THE DINER",
                   track_number: 8,
                   duration_ms: 186_346
                 },
                 %Track{
                   id: nil,
                   provider_ids: %{spotify: "7DpUoxGSdlDHfqCYj0otzU"},
                   name: "BITTERSUITE",
                   track_number: 9,
                   duration_ms: 298_440
                 },
                 %Track{
                   id: nil,
                   provider_ids: %{spotify: "2prqm9sPLj10B4Wg0wE5x9"},
                   name: "BLUE",
                   track_number: 10,
                   duration_ms: 343_120
                 }
               ]
             } = album
    end

    test "returns an error from an unknown unique identifier", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/albums/4SLYa6PnWEEC6WyIEaQagI"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        response: "spotify_api/albums/get_album/error.json",
        status: 404
      )

      id = "4SLYa6PnWEEC6WyIEaQagI"

      {{:error, reason}, logs} = with_log(fn -> SpotifyApi.get_album(id) end)

      assert reason == "Spotify API error: 404"

      assert logs =~
               "[error] Spotify API unexpected status: 404 - %{\"error\" => %{\"message\" => \"Resource not found\", \"status\" => 404}}"
    end
  end
end
