defmodule PremiereEcoute.Discography.Services.EnrichDiscographyTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Services.EnrichDiscography
  alias PremiereEcouteCore.Cache

  setup {Req.Test, :verify_on_exit!}

  setup do
    Cache.put(:tokens, :spotify, "test_spotify_token")
    :ok
  end

  # Billie Eilish spotify ID used in fixtures
  @artist_spotify_id "6qqNVTkY8uBg9cP3Jd7DAH"
  @album_id_1 "7aJuG4TFXa2hmE4z1yxc3n"
  @album_id_2 "5tzRuO6GP7WRvP3rEOPAO9"

  defp artist_fixture(attrs \\ %{}) do
    {:ok, artist} =
      Artist.create(struct(Artist, Map.merge(%{name: "Billie Eilish", provider_ids: %{spotify: @artist_spotify_id}}, attrs)))

    artist
  end

  defp expect_get_artist_albums(response \\ "spotify_api/artists/get_artist_albums/two_albums.json") do
    ApiMock.expect(SpotifyApi,
      path: {:get, "/v1/artists/#{@artist_spotify_id}/albums"},
      response: response,
      status: 200
    )
  end

  # AIDEV-NOTE: album fetches run in parallel via TaskSupervisor; stub (not expect) is required
  # to avoid FIFO queue ordering issues when both tasks consume from the same plug mock queue.
  defp stub_get_albums do
    responses = %{
      "/v1/albums/#{@album_id_1}" => ApiMock.payload("spotify_api/albums/get_album/response.json"),
      "/v1/albums/#{@album_id_2}" => ApiMock.payload("spotify_api/albums/get_album/happier_than_ever.json")
    }

    Req.Test.stub(SpotifyApi, fn conn ->
      body = Map.fetch!(responses, conn.request_path)
      conn |> Plug.Conn.put_status(200) |> Req.Test.json(body)
    end)
  end

  describe "enrich_discography/1" do
    test "fetches all albums and creates them in the database" do
      artist = artist_fixture()
      expect_get_artist_albums()
      stub_get_albums()

      {:ok, albums} = EnrichDiscography.enrich_discography(artist)

      assert length(albums) == 2
      spotify_ids = Enum.map(albums, & &1.provider_ids[:spotify])
      assert @album_id_1 in spotify_ids
      assert @album_id_2 in spotify_ids
    end

    test "persists albums to the database" do
      artist = artist_fixture()
      expect_get_artist_albums()
      stub_get_albums()

      {:ok, _} = EnrichDiscography.enrich_discography(artist)

      assert Album.get_by(provider_ids: %{spotify: @album_id_1}) != nil
      assert Album.get_by(provider_ids: %{spotify: @album_id_2}) != nil
    end

    test "does not create duplicate albums when called twice" do
      artist = artist_fixture()
      expect_get_artist_albums()
      stub_get_albums()
      {:ok, _} = EnrichDiscography.enrich_discography(artist)

      expect_get_artist_albums()
      {:ok, albums} = EnrichDiscography.enrich_discography(artist)

      assert length(albums) == 2
      assert length(Album.all()) == 2
    end

    test "returns error when artist has no spotify ID" do
      artist = artist_fixture(%{provider_ids: %{}})

      assert EnrichDiscography.enrich_discography(artist) == {:error, :no_spotify_id}
    end

    test "returns error when artist has no provider_ids at all" do
      artist = %Artist{name: "Unknown", provider_ids: %{}}

      assert EnrichDiscography.enrich_discography(artist) == {:error, :no_spotify_id}
    end

    test "returns empty list when spotify returns no albums" do
      artist = artist_fixture()

      ApiMock.expect(SpotifyApi,
        path: {:get, "/v1/artists/#{@artist_spotify_id}/albums"},
        body: %{"href" => "...", "limit" => 20, "next" => nil, "offset" => 0, "previous" => nil, "total" => 0, "items" => []},
        status: 200
      )

      {:ok, albums} = EnrichDiscography.enrich_discography(artist)

      assert albums == []
    end

    test "album tracks are persisted" do
      artist = artist_fixture()
      expect_get_artist_albums()
      stub_get_albums()

      {:ok, _} = EnrichDiscography.enrich_discography(artist)

      album = Album.get_by(provider_ids: %{spotify: @album_id_1})
      assert length(album.tracks) == 10
      assert hd(album.tracks).name == "SKINNY"
    end
  end
end
