defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.AlbumsTest do
  use PremiereEcoute.DataCase

  import ExUnit.CaptureLog

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcouteCore.Cache

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Albums
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
               explicit: false,
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

    test "returns album marked as explicit when all tracks are explicit", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/albums/5K4W6rqBFWDnAN6FQUkS6x"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        response: "spotify_api/albums/get_album/explicit_album.json",
        status: 200
      )

      {:ok, album} = SpotifyApi.get_album("5K4W6rqBFWDnAN6FQUkS6x")

      assert %Album{
               provider_ids: %{spotify: "5K4W6rqBFWDnAN6FQUkS6x"},
               name: "The Marshall Mathers LP (Explicit)",
               artists: [%Artist{name: "Eminem"}],
               total_tracks: 3,
               explicit: true,
               tracks: [
                 %Track{name: "The Way I Am", track_number: 1, explicit: true},
                 %Track{name: "Stan", track_number: 2, explicit: true},
                 %Track{name: "Kim", track_number: 3, explicit: true}
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

  describe "parse_album_with_tracks/1" do
    defp spotify_response(tracks) do
      %{
        "id" => "abc123",
        "name" => "Test Album",
        "release_date" => "2024-01-01",
        "release_date_precision" => "day",
        "total_tracks" => length(tracks),
        "images" => [],
        "artists" => [%{"id" => "art1", "name" => "Test Artist", "type" => "artist"}],
        "tracks" => %{"items" => tracks}
      }
    end

    defp track(id, name, number, explicit) do
      %{
        "id" => id,
        "name" => name,
        "track_number" => number,
        "duration_ms" => 200_000,
        "explicit" => explicit
      }
    end

    test "marks album as non-explicit when all tracks have explicit: false" do
      data = spotify_response([
        track("t1", "Clean Track One", 1, false),
        track("t2", "Clean Track Two", 2, false)
      ])

      album = Albums.parse_album_with_tracks(data)

      assert album.explicit == false
      assert Enum.all?(album.tracks, &(&1.explicit == false))
    end

    test "marks album as explicit when all tracks are explicit" do
      data = spotify_response([
        track("t1", "Explicit Track One", 1, true),
        track("t2", "Explicit Track Two", 2, true)
      ])

      album = Albums.parse_album_with_tracks(data)

      assert album.explicit == true
      assert Enum.all?(album.tracks, &(&1.explicit == true))
    end

    test "marks album as explicit when at least one track is explicit" do
      data = spotify_response([
        track("t1", "Clean Track", 1, false),
        track("t2", "Explicit Track", 2, true),
        track("t3", "Another Clean Track", 3, false)
      ])

      album = Albums.parse_album_with_tracks(data)

      assert album.explicit == true
      assert Enum.at(album.tracks, 0).explicit == false
      assert Enum.at(album.tracks, 1).explicit == true
      assert Enum.at(album.tracks, 2).explicit == false
    end

    test "treats missing explicit field in track response as non-explicit" do
      data = spotify_response([
        %{"id" => "t1", "name" => "Track", "track_number" => 1, "duration_ms" => 200_000}
      ])

      album = Albums.parse_album_with_tracks(data)

      assert album.explicit == false
      assert Enum.at(album.tracks, 0).explicit == false
    end
  end
end
