defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.SearchTracksTest do
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

  describe "search_tracks/1" do
    test "searches tracks with a bare query", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/search"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        params: %{"q" => "daft punk", "type" => "track", "limit" => "20"},
        response: "spotify_api/search/search_tracks/query.json",
        status: 200
      )

      {:ok, tracks} = SpotifyApi.search_tracks(query: "daft punk")

      assert [
               %Track{
                 provider: :spotify,
                 track_id: "1pKYYY0dkg23sQQXi0Q5zN",
                 name: "Around the World",
                 track_number: 7,
                 duration_ms: 429_533
               }
               | _
             ] = tracks
    end

    test "searches tracks filtered by artist", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/search"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        params: %{"q" => "artist:daft punk", "type" => "track", "limit" => "20"},
        response: "spotify_api/search/search_tracks/artist.json",
        status: 200
      )

      {:ok, tracks} = SpotifyApi.search_tracks(artist: "daft punk")

      assert [
               %Track{
                 provider: :spotify,
                 track_id: "1pKYYY0dkg23sQQXi0Q5zN",
                 name: "Around the World",
                 track_number: 7,
                 duration_ms: 429_533
               }
               | _
             ] = tracks
    end

    test "searches tracks filtered by track name", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/search"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        params: %{"q" => "track:one more time", "type" => "track", "limit" => "20"},
        response: "spotify_api/search/search_tracks/track.json",
        status: 200
      )

      {:ok, tracks} = SpotifyApi.search_tracks(track: "one more time")

      assert [
               %Track{
                 provider: :spotify,
                 track_id: "0DiWol3AO6WpXZgp0goxAV",
                 name: "One More Time",
                 track_number: 1,
                 duration_ms: 320_357
               }
               | _
             ] = tracks
    end

    test "searches tracks filtered by album", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/search"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        params: %{"q" => "album:discovery", "type" => "track", "limit" => "20"},
        response: "spotify_api/search/search_tracks/album.json",
        status: 200
      )

      {:ok, tracks} = SpotifyApi.search_tracks(album: "discovery")

      assert [
               %Track{
                 provider: :spotify,
                 track_id: "2LD2gT7gwAurzdQDQtILds",
                 name: "Veridis Quo",
                 track_number: 11,
                 duration_ms: 345_186
               }
               | _
             ] = tracks
    end
  end
end
