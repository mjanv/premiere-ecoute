defmodule PremiereEcoute.Discography.Services.EnrichAlbumLinksTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.MusicProvider.TidalApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Services.EnrichAlbumLinks
  alias PremiereEcouteCore.Cache

  setup {Req.Test, :verify_on_exit!}

  setup do
    Cache.put(:tokens, :spotify, "test_spotify_token")
    Cache.put(:tokens, :tidal, "test_tidal_token")
    :ok
  end

  defp ram_fixture(attrs \\ %{}) do
    {:ok, artist} = Artist.create_if_not_exists(%{name: "Daft Punk"})

    {:ok, album} =
      Album.create(
        struct(
          Album,
          Map.merge(
            %{
              name: "Random Access Memories",
              provider_ids: %{spotify: "4m2880jivSbbyEGAKfITCa"},
              artists: [artist],
              release_date: ~D[2013-05-17],
              cover_url: "https://example.com/cover.jpg",
              total_tracks: 13,
              tracks: [
                %Track{
                  provider_ids: %{spotify: "track001"},
                  name: "Give Life Back to Music",
                  track_number: 1,
                  duration_ms: 275_000
                }
              ]
            },
            attrs
          )
        )
      )

    album
  end

  defp expect_wikipedia(response \\ "wikipedia_api/search/search_album/response.json") do
    ApiMock.expect(WikipediaApi, path: {:get, "/w/api.php"}, response: response, status: 200)
  end

  defp expect_wikipedia_empty do
    ApiMock.expect(WikipediaApi,
      path: {:get, "/w/api.php"},
      body: %{"batchcomplete" => "", "query" => %{"searchinfo" => %{"totalhits" => 0}, "search" => []}},
      status: 200
    )
  end

  defp expect_deezer(response \\ "deezer_api/albums/search_album/response.json") do
    ApiMock.expect(DeezerApi, path: {:get, "/search/album"}, response: response, status: 200)
  end

  defp expect_deezer_empty do
    ApiMock.expect(DeezerApi,
      path: {:get, "/search/album"},
      body: %{"data" => [], "total" => 0},
      status: 200
    )
  end

  defp expect_spotify(response \\ "spotify_api/search/search_for_item/album_exact.json") do
    ApiMock.expect(SpotifyApi, path: {:get, "/v1/search"}, response: response, status: 200)
  end

  defp expect_spotify_empty do
    ApiMock.expect(SpotifyApi,
      path: {:get, "/v1/search"},
      body: %{"albums" => %{"items" => [], "total" => 0}},
      status: 200
    )
  end

  defp expect_tidal(response \\ "tidal_api/albums/search_album/response.json") do
    ApiMock.expect(TidalApi,
      path: {:get, "/v2/searchResults/Random%20Access%20Memories%20Daft%20Punk"},
      response: response,
      status: 200
    )
  end

  defp expect_tidal_empty do
    ApiMock.expect(TidalApi,
      path: {:get, "/v2/searchResults/Random%20Access%20Memories%20Daft%20Punk"},
      body: %{"data" => [], "included" => [], "links" => %{}},
      status: 200
    )
  end

  describe "enrich_album/1 - wikipedia" do
    test "fetches wikipedia URL and stores it in external_links" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_tidal()

      {:ok, updated} = EnrichAlbumLinks.enrich_album(album)

      assert updated.external_links["wikipedia"] == "https://en.wikipedia.org/wiki/Random%20Access%20Memories"
    end

    test "persists the wikipedia URL to the database" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_tidal()

      {:ok, _} = EnrichAlbumLinks.enrich_album(album)

      assert Album.get(album.id).external_links["wikipedia"] == "https://en.wikipedia.org/wiki/Random%20Access%20Memories"
    end

    test "skips album that already has a wikipedia link" do
      album = ram_fixture(%{external_links: %{"wikipedia" => "https://en.wikipedia.org/wiki/Random_Access_Memories"}})
      expect_deezer()
      expect_tidal()

      {:ok, returned} = EnrichAlbumLinks.enrich_album(album)

      assert returned.external_links["wikipedia"] == "https://en.wikipedia.org/wiki/Random_Access_Memories"
    end

    test "skips album previously confirmed as not found" do
      album = ram_fixture(%{external_links: %{"wikipedia" => nil}})
      expect_deezer()
      expect_tidal()

      {:ok, returned} = EnrichAlbumLinks.enrich_album(album)

      assert Map.has_key?(returned.external_links, "wikipedia")
      assert is_nil(returned.external_links["wikipedia"])
    end

    test "stores nil sentinel when wikipedia has no results" do
      album = ram_fixture()
      expect_wikipedia_empty()
      expect_deezer()
      expect_tidal()

      {:ok, updated} = EnrichAlbumLinks.enrich_album(album)

      assert Map.has_key?(Album.get(album.id).external_links, "wikipedia")
      assert is_nil(Album.get(album.id).external_links["wikipedia"])
      assert updated.external_links["wikipedia"] == nil
    end
  end

  describe "enrich_album/1 - deezer" do
    test "fetches deezer ID and stores it in provider_ids" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_tidal()

      {:ok, updated} = EnrichAlbumLinks.enrich_album(album)

      assert updated.provider_ids[:deezer] == "25834745"
    end

    test "persists the deezer ID to the database" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_tidal()

      {:ok, _} = EnrichAlbumLinks.enrich_album(album)

      assert Album.get(album.id).provider_ids[:deezer] == "25834745"
    end

    test "skips album that already has a deezer ID" do
      album = ram_fixture(%{provider_ids: %{spotify: "4m2880jivSbbyEGAKfITCa", deezer: "25834745"}})
      expect_wikipedia()
      expect_tidal()

      {:ok, returned} = EnrichAlbumLinks.enrich_album(album)

      assert returned.provider_ids[:deezer] == "25834745"
    end

    test "stores nil sentinel when deezer has no results" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer_empty()
      expect_tidal()

      {:ok, updated} = EnrichAlbumLinks.enrich_album(album)

      assert Map.has_key?(Album.get(album.id).provider_ids, :deezer)
      assert is_nil(updated.provider_ids[:deezer])
    end
  end

  describe "enrich_album/1 - spotify" do
    test "fetches spotify ID and stores it in provider_ids" do
      album = ram_fixture(%{provider_ids: %{}})
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, updated} = EnrichAlbumLinks.enrich_album(album)

      assert updated.provider_ids[:spotify] == "4m2880jivSbbyEGAKfITCa"
    end

    test "persists the spotify ID to the database" do
      album = ram_fixture(%{provider_ids: %{}})
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, _} = EnrichAlbumLinks.enrich_album(album)

      assert Album.get(album.id).provider_ids[:spotify] == "4m2880jivSbbyEGAKfITCa"
    end

    test "skips album that already has a spotify ID" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_tidal()

      {:ok, returned} = EnrichAlbumLinks.enrich_album(album)

      assert returned.provider_ids[:spotify] == "4m2880jivSbbyEGAKfITCa"
    end

    test "stores nil sentinel when spotify has no results" do
      album = ram_fixture(%{provider_ids: %{}})
      expect_wikipedia()
      expect_deezer()
      expect_spotify_empty()
      expect_tidal()

      {:ok, updated} = EnrichAlbumLinks.enrich_album(album)

      assert Map.has_key?(Album.get(album.id).provider_ids, :spotify)
      assert is_nil(updated.provider_ids[:spotify])
    end
  end

  describe "enrich_album/1 - tidal" do
    test "fetches tidal ID and stores it in provider_ids" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_tidal()

      {:ok, updated} = EnrichAlbumLinks.enrich_album(album)

      assert updated.provider_ids[:tidal] == "77646169"
    end

    test "persists the tidal ID to the database" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_tidal()

      {:ok, _} = EnrichAlbumLinks.enrich_album(album)

      assert Album.get(album.id).provider_ids[:tidal] == "77646169"
    end

    test "skips album that already has a tidal ID" do
      album = ram_fixture(%{provider_ids: %{spotify: "4m2880jivSbbyEGAKfITCa", tidal: "77646169"}})
      expect_wikipedia()
      expect_deezer()

      {:ok, returned} = EnrichAlbumLinks.enrich_album(album)

      assert returned.provider_ids[:tidal] == "77646169"
    end

    test "stores nil sentinel when tidal has no results" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_tidal_empty()

      {:ok, updated} = EnrichAlbumLinks.enrich_album(album)

      assert Map.has_key?(Album.get(album.id).provider_ids, :tidal)
      assert is_nil(updated.provider_ids[:tidal])
    end
  end
end
