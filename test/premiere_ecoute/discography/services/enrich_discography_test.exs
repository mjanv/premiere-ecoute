defmodule PremiereEcoute.Discography.Services.EnrichDiscographyTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Services.EnrichDiscography

  # Billie Eilish spotify ID used in fixtures
  @artist_spotify_id "6qqNVTkY8uBg9cP3Jd7DAH"
  @album_id_1 "7aJuG4TFXa2hmE4z1yxc3n"
  @album_id_2 "5tzRuO6GP7WRvP3rEOPAO9"

  defp artist_fixture(attrs \\ %{}) do
    {:ok, artist} =
      Artist.create(struct(Artist, Map.merge(%{name: "Billie Eilish", provider_ids: %{spotify: @artist_spotify_id}}, attrs)))

    artist
  end

  defp expect_get_artist_albums do
    expect(SpotifyApi, :get_artist_albums, fn _id ->
      {:ok,
       [
         %{provider_ids: %{spotify: @album_id_1}},
         %{provider_ids: %{spotify: @album_id_2}}
       ]}
    end)
  end

  # AIDEV-NOTE: album fetches run in parallel via TaskSupervisor; stub (not expect) is required
  # to avoid FIFO queue ordering issues when both tasks consume from the same mock queue.
  defp stub_get_albums do
    album_1 = %Album{
      provider_ids: %{spotify: @album_id_1},
      name: "HIT ME HARD AND SOFT",
      release_date: ~D[2024-05-17],
      cover_url: "https://i.scdn.co/image/ab67616d0000b27371d62ea7ea8a5be92d3c1f62",
      total_tracks: 10,
      tracks: [
        %Album.Track{provider_ids: %{spotify: "1CsMKhwEmNnmvHUuO5nryA"}, name: "SKINNY", track_number: 1, duration_ms: 219_733},
        %Album.Track{provider_ids: %{spotify: "629DixmZGHc7ILtEntuiWE"}, name: "LUNCH", track_number: 2, duration_ms: 179_586},
        %Album.Track{provider_ids: %{spotify: "7BRD7x5pt8Lqa1eGYC4dzj"}, name: "CHIHIRO", track_number: 3, duration_ms: 303_440},
        %Album.Track{
          provider_ids: %{spotify: "6dOtVTDdiauQNBQEDOtlAB"},
          name: "BIRDS OF A FEATHER",
          track_number: 4,
          duration_ms: 210_373
        },
        %Album.Track{
          provider_ids: %{spotify: "3QaPy1KgI7nu9FJEQUgn6h"},
          name: "WILDFLOWER",
          track_number: 5,
          duration_ms: 261_466
        },
        %Album.Track{
          provider_ids: %{spotify: "6TGd66r0nlPaYm3KIoI7ET"},
          name: "THE GREATEST",
          track_number: 6,
          duration_ms: 293_840
        },
        %Album.Track{
          provider_ids: %{spotify: "6fPan2saHdFaIHuTSatORv"},
          name: "L'AMOUR DE MA VIE",
          track_number: 7,
          duration_ms: 333_986
        },
        %Album.Track{
          provider_ids: %{spotify: "1LLUoftvmTjVNBHZoQyveF"},
          name: "THE DINER",
          track_number: 8,
          duration_ms: 186_346
        },
        %Album.Track{
          provider_ids: %{spotify: "7DpUoxGSdlDHfqCYj0otzU"},
          name: "BITTERSUITE",
          track_number: 9,
          duration_ms: 298_440
        },
        %Album.Track{provider_ids: %{spotify: "2prqm9sPLj10B4Wg0wE5x9"}, name: "BLUE", track_number: 10, duration_ms: 343_120}
      ]
    }

    album_2 = %Album{
      provider_ids: %{spotify: @album_id_2},
      name: "Happier Than Ever",
      release_date: ~D[2021-07-30],
      cover_url: "https://i.scdn.co/image/ab67616d0000b273e1317227c6c759e01beae66e",
      total_tracks: 1,
      tracks: [
        %Album.Track{
          provider_ids: %{spotify: "5SjTgj5CiqLEAMfNVX6LGT"},
          name: "Getting Older",
          track_number: 1,
          duration_ms: 243_907
        }
      ]
    }

    stub(SpotifyApi, :get_album, fn
      "7aJuG4TFXa2hmE4z1yxc3n" -> {:ok, album_1}
      "5tzRuO6GP7WRvP3rEOPAO9" -> {:ok, album_2}
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

      expect(SpotifyApi, :get_artist_albums, fn _id -> {:ok, []} end)

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
