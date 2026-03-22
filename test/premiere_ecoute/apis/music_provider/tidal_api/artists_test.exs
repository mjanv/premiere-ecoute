defmodule PremiereEcoute.Apis.MusicProvider.TidalApi.ArtistsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.TidalApi
  alias PremiereEcoute.Discography.Artist

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup_all do
    token = UUID.uuid4()
    PremiereEcouteCore.Cache.put(:tokens, :tidal, token)
    {:ok, %{token: token}}
  end

  describe "get_artist/1" do
    test "fetches an artist by Tidal ID", %{token: token} do
      ApiMock.expect(
        TidalApi,
        path: {:get, "/v2/artists"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/vnd.api+json"}
        ],
        response: "tidal_api/artists/get_artist/response.json",
        status: 200
      )

      {:ok, artist} = TidalApi.get_artist("7804")

      assert %Artist{
               id: nil,
               provider_ids: %{tidal: "7804"},
               name: "JAŸ-Z",
               images: [
                 %Artist.Image{
                   url: "https://resources.tidal.com/images/83d34f7b/38ba/4898/bfe9/1d9ba9cd934d/750x750.jpg",
                   width: 750,
                   height: 750
                 },
                 %Artist.Image{
                   url: "https://resources.tidal.com/images/83d34f7b/38ba/4898/bfe9/1d9ba9cd934d/480x480.jpg",
                   width: 480,
                   height: 480
                 },
                 %Artist.Image{
                   url: "https://resources.tidal.com/images/83d34f7b/38ba/4898/bfe9/1d9ba9cd934d/320x320.jpg",
                   width: 320,
                   height: 320
                 },
                 %Artist.Image{
                   url: "https://resources.tidal.com/images/83d34f7b/38ba/4898/bfe9/1d9ba9cd934d/160x160.jpg",
                   width: 160,
                   height: 160
                 }
               ]
             } = artist
    end
  end

  describe "search_artist/1" do
    test "searches artists by name", %{token: token} do
      ApiMock.expect(
        TidalApi,
        path: {:get, "/v2/searchResults/daft%20punk"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/vnd.api+json"}
        ],
        response: "tidal_api/artists/search_artist/response.json",
        status: 200
      )

      {:ok, artists} = TidalApi.search_artist("daft punk")

      assert [
               %{
                 tidal_id: "8847",
                 name: "Daft Punk",
                 popularity: 0.9363624453544617
               }
             ] = artists
    end
  end

  describe "get_artist_albums/1" do
    test "fetches albums for an artist by Tidal ID", %{token: token} do
      ApiMock.expect(
        TidalApi,
        path: {:get, "/v2/artists"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/vnd.api+json"}
        ],
        response: "tidal_api/artists/get_artist_albums/response.json",
        status: 200
      )

      {:ok, albums} = TidalApi.get_artist_albums("7804")

      assert length(albums) == 20

      assert %{
               provider_ids: %{tidal: "113655760"},
               name: "MOOD 4 EVA (feat. Oumou Sangaré) (Extended Version)",
               release_date: ~D[2019-07-19],
               cover_url: "https://tidal.com/browse/album/113655760"
             } = hd(albums)
    end
  end
end
