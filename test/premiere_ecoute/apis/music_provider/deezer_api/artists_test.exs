defmodule PremiereEcoute.Apis.MusicProvider.DeezerApi.ArtistsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi

  alias PremiereEcoute.Discography.Artist

  setup {Req.Test, :verify_on_exit!}

  describe "get_artist/1" do
    test "fetches an artist by Deezer ID" do
      ApiMock.expect(
        DeezerApi,
        path: {:get, "/artist/27"},
        headers: [{"content-type", "application/json"}],
        response: "deezer_api/artists/get_artist/response.json",
        status: 200
      )

      {:ok, artist} = DeezerApi.get_artist("27")

      assert %Artist{
               id: nil,
               provider_ids: %{deezer: "27"},
               name: "Daft Punk",
               images: [
                 %Artist.Image{
                   url: "https://cdn-images.dzcdn.net/images/artist/638e69b9caaf9f9f3f8826febea7b543/56x56-000000-80-0-0.jpg",
                   height: 56,
                   width: 56
                 },
                 %Artist.Image{
                   url: "https://cdn-images.dzcdn.net/images/artist/638e69b9caaf9f9f3f8826febea7b543/250x250-000000-80-0-0.jpg",
                   height: 250,
                   width: 250
                 },
                 %Artist.Image{
                   url: "https://cdn-images.dzcdn.net/images/artist/638e69b9caaf9f9f3f8826febea7b543/500x500-000000-80-0-0.jpg",
                   height: 500,
                   width: 500
                 },
                 %Artist.Image{
                   url: "https://cdn-images.dzcdn.net/images/artist/638e69b9caaf9f9f3f8826febea7b543/1000x1000-000000-80-0-0.jpg",
                   height: 1000,
                   width: 1000
                 }
               ]
             } = artist
    end
  end

  describe "get_artist_albums/1" do
    test "fetches albums for an artist by Deezer ID" do
      ApiMock.expect(
        DeezerApi,
        path: {:get, "/artist/27/albums"},
        headers: [{"content-type", "application/json"}],
        response: "deezer_api/artists/get_artist_albums/response.json",
        status: 200
      )

      {:ok, albums} = DeezerApi.get_artist_albums("27")

      assert length(albums) == 25

      assert %{
               provider_ids: %{deezer: "494309801"},
               name: "Random Access Memories (Drumless Edition)",
               release_date: ~D[2023-11-17],
               cover_url: "https://api.deezer.com/album/494309801/image"
             } = hd(albums)
    end
  end
end
