defmodule PremiereEcoute.Discography.Services.EnrichArtistTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicMetadata.GeniusApi
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.MusicProvider.TidalApi
  alias PremiereEcoute.Apis.Video.YoutubeApi
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Services.EnrichArtist
  alias PremiereEcouteCore.Cache

  setup {Req.Test, :verify_on_exit!}

  setup do
    Cache.put(:tokens, :spotify, "test_spotify_token")
    Cache.put(:tokens, :tidal, "test_tidal_token")
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

  defp expect_genius(response \\ "genius_api/artists/search_artist/response.json") do
    ApiMock.expect(GeniusApi, path: {:get, "/search"}, response: response, status: 200)
  end

  defp expect_genius_empty do
    ApiMock.expect(GeniusApi,
      path: {:get, "/search"},
      body: %{"meta" => %{"status" => 200}, "response" => %{"hits" => []}},
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

  defp expect_tidal(response \\ "tidal_api/artists/search_artist/response.json") do
    ApiMock.expect(TidalApi, path: {:get, "/v2/searchResults/Daft%20Punk"}, response: response, status: 200)
  end

  defp expect_tidal_empty do
    ApiMock.expect(TidalApi,
      path: {:get, "/v2/searchResults/Daft%20Punk"},
      body: %{"data" => [], "included" => [], "links" => %{}},
      status: 200
    )
  end

  defp expect_youtube_music(response \\ "youtube_api/search/search_artist/response.json") do
    ApiMock.expect(YoutubeApi, path: {:get, "/youtube/v3/search"}, response: response, status: 200)
  end

  defp expect_youtube_music_empty do
    ApiMock.expect(YoutubeApi,
      path: {:get, "/youtube/v3/search"},
      body: %{"items" => []},
      status: 200
    )
  end

  defp expect_all do
    expect_wikipedia()
    expect_genius()
    expect_deezer()
    expect_spotify()
    expect_tidal()
    expect_youtube_music()
  end

  describe "enrich_artist/1 - wikipedia" do
    test "fetches wikipedia URL and stores it in external_links" do
      artist = artist_fixture()
      expect_all()

      {:ok, updated} = EnrichArtist.enrich_artist(artist)

      assert updated.external_links[:wikipedia] == "https://en.wikipedia.org/wiki/Daft%20Punk"
    end

    test "persists the wikipedia URL to the database" do
      artist = artist_fixture()
      expect_all()

      {:ok, _} = EnrichArtist.enrich_artist(artist)

      assert Artist.get(artist.id).external_links["wikipedia"] == "https://en.wikipedia.org/wiki/Daft%20Punk"
    end

    test "overwrites existing wikipedia link with freshly fetched value" do
      artist = artist_fixture(%{external_links: %{wikipedia: "https://en.wikipedia.org/wiki/Daft_Punk"}})
      expect_all()

      {:ok, returned} = EnrichArtist.enrich_artist(artist)

      assert returned.external_links[:wikipedia] == "https://en.wikipedia.org/wiki/Daft%20Punk"
    end

    test "stores nil when wikipedia has no results" do
      artist = artist_fixture()
      expect_wikipedia_empty()
      expect_genius()
      expect_deezer()
      expect_spotify()
      expect_tidal()
      expect_youtube_music()

      {:ok, updated} = EnrichArtist.enrich_artist(artist)

      assert Map.has_key?(Artist.get(artist.id).external_links, "wikipedia")
      assert is_nil(Artist.get(artist.id).external_links["wikipedia"])
      assert updated.external_links[:wikipedia] == nil
    end
  end

  describe "enrich_artist/1 - genius" do
    test "fetches genius URL and stores it in external_links" do
      artist = artist_fixture()
      expect_all()

      {:ok, updated} = EnrichArtist.enrich_artist(artist)

      assert updated.external_links[:genius] == "https://genius.com/artists/Daft-punk"
    end

    test "persists the genius URL to the database" do
      artist = artist_fixture()
      expect_all()

      {:ok, _} = EnrichArtist.enrich_artist(artist)

      assert Artist.get(artist.id).external_links["genius"] == "https://genius.com/artists/Daft-punk"
    end

    test "overwrites existing genius link with freshly fetched value" do
      artist = artist_fixture(%{external_links: %{genius: "https://genius.com/artists/Daft-punk"}})
      expect_all()

      {:ok, returned} = EnrichArtist.enrich_artist(artist)

      assert returned.external_links[:genius] == "https://genius.com/artists/Daft-punk"
    end

    test "stores nil when genius has no results" do
      artist = artist_fixture()
      expect_wikipedia()
      expect_genius_empty()
      expect_deezer()
      expect_spotify()
      expect_tidal()
      expect_youtube_music()

      {:ok, updated} = EnrichArtist.enrich_artist(artist)

      assert Map.has_key?(Artist.get(artist.id).external_links, "genius")
      assert is_nil(updated.external_links[:genius])
    end
  end

  describe "enrich_artist/1 - deezer" do
    test "fetches deezer ID and stores it in provider_ids" do
      artist = artist_fixture()
      expect_all()

      {:ok, updated} = EnrichArtist.enrich_artist(artist)

      assert updated.provider_ids[:deezer] == "1312"
    end

    test "persists the deezer ID to the database" do
      artist = artist_fixture()
      expect_all()

      {:ok, _} = EnrichArtist.enrich_artist(artist)

      assert Artist.get(artist.id).provider_ids[:deezer] == "1312"
    end

    test "overwrites existing deezer ID with freshly fetched value" do
      artist = artist_fixture(%{provider_ids: %{spotify: "4tZwfgrHOc3mvqYlEYSvVi", deezer: "1312"}})
      expect_all()

      {:ok, returned} = EnrichArtist.enrich_artist(artist)

      assert returned.provider_ids[:deezer] == "1312"
    end

    test "stores nil when deezer has no results" do
      artist = artist_fixture()
      expect_wikipedia()
      expect_genius()
      expect_deezer_empty()
      expect_spotify()
      expect_tidal()
      expect_youtube_music()

      {:ok, updated} = EnrichArtist.enrich_artist(artist)

      assert Map.has_key?(Artist.get(artist.id).provider_ids, :deezer)
      assert is_nil(updated.provider_ids[:deezer])
    end
  end

  describe "enrich_artist/1 - spotify" do
    test "fetches spotify ID and stores it in provider_ids" do
      artist = artist_fixture(%{provider_ids: %{}})
      expect_all()

      {:ok, updated} = EnrichArtist.enrich_artist(artist)

      assert updated.provider_ids[:spotify] == "5OlAhdgR13gu6r0MZU8eKj"
    end

    test "persists the spotify ID to the database" do
      artist = artist_fixture(%{provider_ids: %{}})
      expect_all()

      {:ok, _} = EnrichArtist.enrich_artist(artist)

      assert Artist.get(artist.id).provider_ids[:spotify] == "5OlAhdgR13gu6r0MZU8eKj"
    end

    test "overwrites existing spotify ID with freshly fetched value" do
      artist = artist_fixture()
      expect_all()

      {:ok, returned} = EnrichArtist.enrich_artist(artist)

      assert returned.provider_ids[:spotify] == "5OlAhdgR13gu6r0MZU8eKj"
    end

    test "stores nil when spotify has no results" do
      artist = artist_fixture(%{provider_ids: %{}})
      expect_wikipedia()
      expect_genius()
      expect_deezer()
      expect_spotify_empty()
      expect_tidal()
      expect_youtube_music()

      {:ok, updated} = EnrichArtist.enrich_artist(artist)

      assert Map.has_key?(Artist.get(artist.id).provider_ids, :spotify)
      assert is_nil(updated.provider_ids[:spotify])
    end
  end

  describe "enrich_artist/1 - tidal" do
    test "fetches tidal ID and stores it in provider_ids" do
      artist = artist_fixture()
      expect_all()

      {:ok, updated} = EnrichArtist.enrich_artist(artist)

      assert updated.provider_ids[:tidal] == "8847"
    end

    test "persists the tidal ID to the database" do
      artist = artist_fixture()
      expect_all()

      {:ok, _} = EnrichArtist.enrich_artist(artist)

      assert Artist.get(artist.id).provider_ids[:tidal] == "8847"
    end

    test "overwrites existing tidal ID with freshly fetched value" do
      artist = artist_fixture(%{provider_ids: %{spotify: "4tZwfgrHOc3mvqYlEYSvVi", tidal: "8847"}})
      expect_all()

      {:ok, returned} = EnrichArtist.enrich_artist(artist)

      assert returned.provider_ids[:tidal] == "8847"
    end

    test "stores nil when tidal has no results" do
      artist = artist_fixture()
      expect_wikipedia()
      expect_genius()
      expect_deezer()
      expect_spotify()
      expect_tidal_empty()
      expect_youtube_music()

      {:ok, updated} = EnrichArtist.enrich_artist(artist)

      assert Map.has_key?(Artist.get(artist.id).provider_ids, :tidal)
      assert is_nil(updated.provider_ids[:tidal])
    end
  end

  describe "enrich_artist/1 - youtube_music" do
    test "fetches youtube channel ID and stores it in provider_ids" do
      artist = artist_fixture()
      expect_all()

      {:ok, updated} = EnrichArtist.enrich_artist(artist)

      assert updated.provider_ids[:youtube_music] == "UC_kRDKYrUlrbtrSiyu5Tflg"
    end

    test "persists the youtube channel ID to the database" do
      artist = artist_fixture()
      expect_all()

      {:ok, _} = EnrichArtist.enrich_artist(artist)

      assert Artist.get(artist.id).provider_ids[:youtube_music] == "UC_kRDKYrUlrbtrSiyu5Tflg"
    end

    test "overwrites existing youtube_music ID with freshly fetched value" do
      artist = artist_fixture(%{provider_ids: %{spotify: "4tZwfgrHOc3mvqYlEYSvVi", youtube_music: "UC_kRDKYrUlrbtrSiyu5Tflg"}})
      expect_all()

      {:ok, returned} = EnrichArtist.enrich_artist(artist)

      assert returned.provider_ids[:youtube_music] == "UC_kRDKYrUlrbtrSiyu5Tflg"
    end

    test "stores nil when youtube_music has no results" do
      artist = artist_fixture()
      expect_wikipedia()
      expect_genius()
      expect_deezer()
      expect_spotify()
      expect_tidal()
      expect_youtube_music_empty()

      {:ok, updated} = EnrichArtist.enrich_artist(artist)

      assert Map.has_key?(Artist.get(artist.id).provider_ids, :youtube_music)
      assert is_nil(updated.provider_ids[:youtube_music])
    end
  end
end
