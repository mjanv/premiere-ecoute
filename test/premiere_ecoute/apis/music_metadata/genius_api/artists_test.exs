defmodule PremiereEcoute.Apis.MusicMetadata.GeniusApi.ArtistsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicMetadata.GeniusApi

  setup {Req.Test, :verify_on_exit!}

  describe "search_artist/1" do
    test "returns primary artist from first song hit" do
      ApiMock.expect(
        GeniusApi,
        path: {:get, "/search"},
        headers: [{"content-type", "application/json"}],
        response: "genius_api/artists/search_artist/response.json",
        status: 200
      )

      {:ok, artist} = GeniusApi.search_artist("Daft Punk")

      assert artist == %{
               id: 13_585,
               name: "Daft Punk",
               url: "https://genius.com/artists/Daft-punk",
               image_url: "https://images.genius.com/626f2887c30a9618cb1fbb383a16f8c1.1000x1000x1.png",
               header_image_url: "https://images.genius.com/65cd354bc41531872aca3356dc06eb83.1000x562x1.jpg",
               is_verified: false,
               followers_count: nil,
               twitter_name: nil,
               instagram_name: nil,
               facebook_name: nil
             }
    end

    test "returns nil when no hits" do
      ApiMock.expect(
        GeniusApi,
        path: {:get, "/search"},
        body: %{"meta" => %{"status" => 200}, "response" => %{"hits" => []}},
        status: 200
      )

      {:ok, result} = GeniusApi.search_artist("zzznomatch")

      assert result == nil
    end
  end

  describe "get_artist/1" do
    test "returns full artist details" do
      ApiMock.expect(
        GeniusApi,
        path: {:get, "/artists/13585"},
        headers: [{"content-type", "application/json"}],
        response: "genius_api/artists/get_artist/response.json",
        status: 200
      )

      {:ok, artist} = GeniusApi.get_artist(13_585)

      assert artist == %{
               id: 13_585,
               name: "Daft Punk",
               url: "https://genius.com/artists/Daft-punk",
               image_url: "https://images.genius.com/626f2887c30a9618cb1fbb383a16f8c1.1000x1000x1.png",
               header_image_url: "https://images.genius.com/65cd354bc41531872aca3356dc06eb83.1000x562x1.jpg",
               is_verified: false,
               followers_count: 1068,
               twitter_name: "daftpunk",
               instagram_name: "daftpunk",
               facebook_name: "DaftPunk"
             }
    end
  end
end
