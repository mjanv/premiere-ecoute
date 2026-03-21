defmodule PremiereEcoute.Discography.Services.EnrichArtistLinksTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Services.EnrichArtistLinks
  alias PremiereEcouteCore.Cache

  setup {Req.Test, :verify_on_exit!}

  setup do
    Cache.put(:tokens, :spotify, "test_spotify_token")
    :ok
  end

  defp artist_fixture(attrs \\ %{}) do
    {:ok, artist} =
      Artist.create(struct(Artist, Map.merge(%{name: "Daft Punk", provider_ids: %{spotify: "4tZwfgrHOc3mvqYlEYSvVi"}}, attrs)))

    artist
  end

  defp expect_wikipedia(response \\ "wikipedia_api/search/search_artist/response.json") do
    ApiMock.expect(WikipediaApi, path: {:get, "/w/api.php"}, response: response, status: 200)
  end

  defp expect_wikipedia_empty do
    ApiMock.expect(WikipediaApi,
      path: {:get, "/w/api.php"},
      body: %{"batchcomplete" => "", "query" => %{"searchinfo" => %{"totalhits" => 0}, "search" => []}},
      status: 200
    )
  end

  defp expect_deezer(response \\ "deezer_api/artists/search_artist/response.json") do
    ApiMock.expect(DeezerApi, path: {:get, "/search/artist"}, response: response, status: 200)
  end

  defp expect_deezer_empty do
    ApiMock.expect(DeezerApi,
      path: {:get, "/search/artist"},
      body: %{"data" => [], "total" => 0},
      status: 200
    )
  end

  defp expect_spotify(response \\ "spotify_api/search/search_for_item/artist.json") do
    ApiMock.expect(SpotifyApi, path: {:get, "/v1/search"}, response: response, status: 200)
  end

  defp expect_spotify_empty do
    ApiMock.expect(SpotifyApi,
      path: {:get, "/v1/search"},
      body: %{"artists" => %{"items" => [], "total" => 0}},
      status: 200
    )
  end

  describe "enrich_artist/1 - wikipedia" do
    test "fetches wikipedia URL and stores it in external_links" do
      artist = artist_fixture()
      expect_wikipedia()
      expect_deezer()

      {:ok, updated} = EnrichArtistLinks.enrich_artist(artist)

      assert updated.external_links["wikipedia"] == "https://en.wikipedia.org/wiki/Daft%20Punk"
    end

    test "persists the wikipedia URL to the database" do
      artist = artist_fixture()
      expect_wikipedia()
      expect_deezer()

      {:ok, _} = EnrichArtistLinks.enrich_artist(artist)

      assert Artist.get(artist.id).external_links["wikipedia"] == "https://en.wikipedia.org/wiki/Daft%20Punk"
    end

    test "skips artist that already has a wikipedia link" do
      artist = artist_fixture(%{external_links: %{"wikipedia" => "https://en.wikipedia.org/wiki/Daft_Punk"}})
      expect_deezer()

      {:ok, returned} = EnrichArtistLinks.enrich_artist(artist)

      assert returned.external_links["wikipedia"] == "https://en.wikipedia.org/wiki/Daft_Punk"
    end

    test "skips artist previously confirmed as not found" do
      artist = artist_fixture(%{external_links: %{"wikipedia" => nil}})
      expect_deezer()

      {:ok, returned} = EnrichArtistLinks.enrich_artist(artist)

      assert Map.has_key?(returned.external_links, "wikipedia")
      assert is_nil(returned.external_links["wikipedia"])
    end

    test "stores nil sentinel when wikipedia has no results" do
      artist = artist_fixture()
      expect_wikipedia_empty()
      expect_deezer()

      {:ok, updated} = EnrichArtistLinks.enrich_artist(artist)

      assert Map.has_key?(Artist.get(artist.id).external_links, "wikipedia")
      assert is_nil(Artist.get(artist.id).external_links["wikipedia"])
      assert updated.external_links["wikipedia"] == nil
    end
  end

  describe "enrich_artist/1 - deezer" do
    test "fetches deezer ID and stores it in provider_ids" do
      artist = artist_fixture()
      expect_wikipedia()
      expect_deezer()

      {:ok, updated} = EnrichArtistLinks.enrich_artist(artist)

      assert updated.provider_ids[:deezer] == "1312"
    end

    test "persists the deezer ID to the database" do
      artist = artist_fixture()
      expect_wikipedia()
      expect_deezer()

      {:ok, _} = EnrichArtistLinks.enrich_artist(artist)

      assert Artist.get(artist.id).provider_ids[:deezer] == "1312"
    end

    test "skips artist that already has a deezer ID" do
      artist = artist_fixture(%{provider_ids: %{spotify: "4tZwfgrHOc3mvqYlEYSvVi", deezer: "1312"}})
      expect_wikipedia()

      {:ok, returned} = EnrichArtistLinks.enrich_artist(artist)

      assert returned.provider_ids[:deezer] == "1312"
    end

    test "stores nil sentinel when deezer has no results" do
      artist = artist_fixture()
      expect_wikipedia()
      expect_deezer_empty()

      {:ok, updated} = EnrichArtistLinks.enrich_artist(artist)

      assert Map.has_key?(Artist.get(artist.id).provider_ids, :deezer)
      assert is_nil(updated.provider_ids[:deezer])
    end
  end

  describe "enrich_artist/1 - spotify" do
    test "fetches spotify ID and stores it in provider_ids" do
      artist = artist_fixture(%{provider_ids: %{}})
      expect_wikipedia()
      expect_deezer()
      expect_spotify()

      {:ok, updated} = EnrichArtistLinks.enrich_artist(artist)

      assert updated.provider_ids[:spotify] == "5OlAhdgR13gu6r0MZU8eKj"
    end

    test "persists the spotify ID to the database" do
      artist = artist_fixture(%{provider_ids: %{}})
      expect_wikipedia()
      expect_deezer()
      expect_spotify()

      {:ok, _} = EnrichArtistLinks.enrich_artist(artist)

      assert Artist.get(artist.id).provider_ids[:spotify] == "5OlAhdgR13gu6r0MZU8eKj"
    end

    test "skips artist that already has a spotify ID" do
      artist = artist_fixture()
      expect_wikipedia()
      expect_deezer()

      {:ok, returned} = EnrichArtistLinks.enrich_artist(artist)

      assert returned.provider_ids[:spotify] == "4tZwfgrHOc3mvqYlEYSvVi"
    end

    test "stores nil sentinel when spotify has no results" do
      artist = artist_fixture(%{provider_ids: %{}})
      expect_wikipedia()
      expect_deezer()
      expect_spotify_empty()

      {:ok, updated} = EnrichArtistLinks.enrich_artist(artist)

      assert Map.has_key?(Artist.get(artist.id).provider_ids, :spotify)
      assert is_nil(updated.provider_ids[:spotify])
    end
  end
end
