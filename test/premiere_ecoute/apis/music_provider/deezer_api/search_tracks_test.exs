defmodule PremiereEcoute.Apis.MusicProvider.DeezerApi.SearchTracksTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi

  alias PremiereEcoute.Discography.Album.Track

  setup {Req.Test, :verify_on_exit!}

  describe "search_tracks/1" do
    test "searches tracks with a bare query" do
      ApiMock.expect(
        DeezerApi,
        path: {:get, "/search"},
        headers: [{"content-type", "application/json"}],
        params: %{"q" => "daft punk"},
        response: "deezer_api/search/search_tracks/query.json",
        status: 200
      )

      {:ok, tracks} = DeezerApi.search_tracks(query: "daft punk")

      assert [
               %Track{
                 provider: :deezer,
                 track_id: "67238732",
                 name: "Instant Crush (feat. Julian Casablancas)",
                 track_number: 0,
                 duration_ms: 337_000
               }
               | _
             ] = tracks
    end

    test "searches tracks filtered by artist" do
      ApiMock.expect(
        DeezerApi,
        path: {:get, "/search"},
        headers: [{"content-type", "application/json"}],
        params: %{"q" => ~s(artist:"daft punk")},
        response: "deezer_api/search/search_tracks/artist.json",
        status: 200
      )

      {:ok, tracks} = DeezerApi.search_tracks(artist: "daft punk")

      assert [
               %Track{
                 provider: :deezer,
                 track_id: "1851933947",
                 name: "Mine (feat. Brenden Praise, Da Capo & Chymamusique)",
                 track_number: 0,
                 duration_ms: 330_000
               }
               | _
             ] = tracks
    end

    test "searches tracks filtered by track name" do
      ApiMock.expect(
        DeezerApi,
        path: {:get, "/search"},
        headers: [{"content-type", "application/json"}],
        params: %{"q" => ~s(track:"one more time")},
        response: "deezer_api/search/search_tracks/track.json",
        status: 200
      )

      {:ok, tracks} = DeezerApi.search_tracks(track: "one more time")

      assert [
               %Track{
                 provider: :deezer,
                 track_id: "5981620",
                 name: "One More Time (As Made Famous By Daft Punk)",
                 track_number: 0,
                 duration_ms: 469_000
               }
               | _
             ] = tracks
    end

    test "searches tracks filtered by album" do
      ApiMock.expect(
        DeezerApi,
        path: {:get, "/search"},
        headers: [{"content-type", "application/json"}],
        params: %{"q" => ~s(album:"discovery")},
        response: "deezer_api/search/search_tracks/album.json",
        status: 200
      )

      {:ok, tracks} = DeezerApi.search_tracks(album: "discovery")

      assert [
               %Track{
                 provider: :deezer,
                 track_id: "1099067",
                 name: "The Discovery (Album Version)",
                 track_number: 0,
                 duration_ms: 1_053_000
               }
               | _
             ] = tracks
    end
  end
end
