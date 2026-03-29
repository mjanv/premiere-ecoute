defmodule PremiereEcoute.Discography.Services.EnrichArtistTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Apis.MusicMetadata.GeniusApi.Mock, as: GeniusApi
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Mock, as: WikipediaApi
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Page
  alias PremiereEcoute.Apis.MusicProvider.DeezerApi.Mock, as: DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.MusicProvider.TidalApi.Mock, as: TidalApi
  alias PremiereEcoute.Apis.Video.YoutubeApi.Mock, as: YoutubeApi
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Services.EnrichArtist

  defp artist_fixture(attrs \\ %{}) do
    {:ok, artist} =
      Artist.create(struct(Artist, Map.merge(%{name: "Daft Punk", provider_ids: %{spotify: "4tZwfgrHOc3mvqYlEYSvVi"}}, attrs)))

    artist
  end

  defp expect_wikipedia do
    expect(WikipediaApi, :search, fn _query ->
      {:ok, [%Page{id: "168310", title: "Daft Punk", url: "https://en.wikipedia.org/wiki/Daft%20Punk"}]}
    end)
  end

  defp expect_wikipedia_empty do
    expect(WikipediaApi, :search, fn _query -> {:ok, []} end)
  end

  defp expect_genius do
    expect(GeniusApi, :search_artist, fn _query ->
      {:ok, %{url: "https://genius.com/artists/Daft-punk", name: "Daft Punk"}}
    end)
  end

  defp expect_genius_empty do
    expect(GeniusApi, :search_artist, fn _query -> {:ok, nil} end)
  end

  defp expect_deezer do
    expect(DeezerApi, :search_artist, fn _query ->
      {:ok, [%{deezer_id: "1312", name: "Daft Punk"}]}
    end)
  end

  defp expect_deezer_empty do
    expect(DeezerApi, :search_artist, fn _query -> {:ok, []} end)
  end

  defp expect_spotify do
    expect(SpotifyApi, :search_artist, fn _query -> {:ok, %{id: "5OlAhdgR13gu6r0MZU8eKj"}} end)
  end

  defp expect_spotify_empty do
    expect(SpotifyApi, :search_artist, fn _query -> {:error, :not_found} end)
  end

  defp expect_tidal do
    expect(TidalApi, :search_artist, fn _query ->
      {:ok, [%{tidal_id: "8847", name: "Daft Punk"}]}
    end)
  end

  defp expect_tidal_empty do
    expect(TidalApi, :search_artist, fn _query -> {:ok, []} end)
  end

  defp expect_youtube_music do
    expect(YoutubeApi, :search_artist, fn _query ->
      {:ok, [%{channel_id: "UC_kRDKYrUlrbtrSiyu5Tflg", name: "Daft Punk"}]}
    end)
  end

  defp expect_youtube_music_empty do
    expect(YoutubeApi, :search_artist, fn _query -> {:ok, []} end)
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
