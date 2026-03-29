defmodule PremiereEcoute.Discography.Services.EnrichAlbumTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Mock, as: WikipediaApi
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Page
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi.Mock, as: DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.MusicProvider.TidalApi.Mock, as: TidalApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Services.EnrichAlbum

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

  defp expect_wikipedia do
    expect(WikipediaApi, :search, fn _query ->
      {:ok,
       [%Page{id: "38898753", title: "Random Access Memories", url: "https://en.wikipedia.org/wiki/Random%20Access%20Memories"}]}
    end)
  end

  defp expect_wikipedia_empty do
    expect(WikipediaApi, :search, fn _query -> {:ok, []} end)
  end

  defp expect_deezer do
    expect(DeezerApi, :search_album, fn _title, _artist -> {:ok, [%{deezer_id: "25834745"}]} end)
  end

  defp expect_deezer_empty do
    expect(DeezerApi, :search_album, fn _title, _artist -> {:ok, []} end)
  end

  defp expect_spotify do
    expect(SpotifyApi, :search_albums, fn _query ->
      {:ok, [%Album{name: "Random Access Memories", provider_ids: %{spotify: "4m2880jivSbbyEGAKfITCa"}}]}
    end)
  end

  defp expect_spotify_empty do
    expect(SpotifyApi, :search_albums, fn _query -> {:ok, []} end)
  end

  defp expect_tidal do
    expect(TidalApi, :search_album, fn _title, _artist -> {:ok, [%{tidal_id: "77646169"}]} end)
  end

  defp expect_tidal_empty do
    expect(TidalApi, :search_album, fn _title, _artist -> {:ok, []} end)
  end

  describe "enrich_album/1 - wikipedia" do
    test "fetches wikipedia URL and stores it in external_links" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, updated} = EnrichAlbum.enrich_album(album)

      assert updated.external_links[:wikipedia] == "https://en.wikipedia.org/wiki/Random%20Access%20Memories"
    end

    test "persists the wikipedia URL to the database" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, _} = EnrichAlbum.enrich_album(album)

      assert Album.get(album.id).external_links["wikipedia"] == "https://en.wikipedia.org/wiki/Random%20Access%20Memories"
    end

    test "overwrites existing wikipedia link with freshly fetched value" do
      album = ram_fixture(%{external_links: %{wikipedia: "https://en.wikipedia.org/wiki/Random_Access_Memories"}})
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, returned} = EnrichAlbum.enrich_album(album)

      assert returned.external_links[:wikipedia] == "https://en.wikipedia.org/wiki/Random%20Access%20Memories"
    end

    test "stores nil when wikipedia has no results" do
      album = ram_fixture()
      expect_wikipedia_empty()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, updated} = EnrichAlbum.enrich_album(album)

      assert Map.has_key?(Album.get(album.id).external_links, "wikipedia")
      assert is_nil(Album.get(album.id).external_links["wikipedia"])
      assert updated.external_links[:wikipedia] == nil
    end
  end

  describe "enrich_album/1 - deezer" do
    test "fetches deezer ID and stores it in provider_ids" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, updated} = EnrichAlbum.enrich_album(album)

      assert updated.provider_ids[:deezer] == "25834745"
    end

    test "persists the deezer ID to the database" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, _} = EnrichAlbum.enrich_album(album)

      assert Album.get(album.id).provider_ids[:deezer] == "25834745"
    end

    test "overwrites existing deezer ID with freshly fetched value" do
      album = ram_fixture(%{provider_ids: %{spotify: "4m2880jivSbbyEGAKfITCa", deezer: "25834745"}})
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, returned} = EnrichAlbum.enrich_album(album)

      assert returned.provider_ids[:deezer] == "25834745"
    end

    test "stores nil when deezer has no results" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer_empty()
      expect_spotify()
      expect_tidal()

      {:ok, updated} = EnrichAlbum.enrich_album(album)

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

      {:ok, updated} = EnrichAlbum.enrich_album(album)

      assert updated.provider_ids[:spotify] == "4m2880jivSbbyEGAKfITCa"
    end

    test "persists the spotify ID to the database" do
      album = ram_fixture(%{provider_ids: %{}})
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, _} = EnrichAlbum.enrich_album(album)

      assert Album.get(album.id).provider_ids[:spotify] == "4m2880jivSbbyEGAKfITCa"
    end

    test "overwrites existing spotify ID with freshly fetched value" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, returned} = EnrichAlbum.enrich_album(album)

      assert returned.provider_ids[:spotify] == "4m2880jivSbbyEGAKfITCa"
    end

    test "stores nil when spotify has no results" do
      album = ram_fixture(%{provider_ids: %{}})
      expect_wikipedia()
      expect_deezer()
      expect_spotify_empty()
      expect_tidal()

      {:ok, updated} = EnrichAlbum.enrich_album(album)

      assert Map.has_key?(Album.get(album.id).provider_ids, :spotify)
      assert is_nil(updated.provider_ids[:spotify])
    end
  end

  describe "enrich_album/1 - tidal" do
    test "fetches tidal ID and stores it in provider_ids" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, updated} = EnrichAlbum.enrich_album(album)

      assert updated.provider_ids[:tidal] == "77646169"
    end

    test "persists the tidal ID to the database" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, _} = EnrichAlbum.enrich_album(album)

      assert Album.get(album.id).provider_ids[:tidal] == "77646169"
    end

    test "overwrites existing tidal ID with freshly fetched value" do
      album = ram_fixture(%{provider_ids: %{spotify: "4m2880jivSbbyEGAKfITCa", tidal: "77646169"}})
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal()

      {:ok, returned} = EnrichAlbum.enrich_album(album)

      assert returned.provider_ids[:tidal] == "77646169"
    end

    test "stores nil when tidal has no results" do
      album = ram_fixture()
      expect_wikipedia()
      expect_deezer()
      expect_spotify()
      expect_tidal_empty()

      {:ok, updated} = EnrichAlbum.enrich_album(album)

      assert Map.has_key?(Album.get(album.id).provider_ids, :tidal)
      assert is_nil(updated.provider_ids[:tidal])
    end
  end
end
