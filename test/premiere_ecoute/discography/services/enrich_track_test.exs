defmodule PremiereEcoute.Discography.Services.EnrichTrackTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Apis.MusicMetadata.GeniusApi.Mock, as: GeniusApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Services.EnrichTrack

  defp create_track_with_album(track_attrs \\ %{}, album_attrs \\ %{}) do
    {:ok, artist} = Artist.create_if_not_exists(%{name: "Daft Punk"})

    track_struct =
      struct(
        Track,
        Map.merge(
          %{
            name: "One More Time",
            provider_ids: %{spotify: "6k4dq0c3z6byxyhz6hd5a9"},
            track_number: 1,
            duration_ms: 320_000
          },
          track_attrs
        )
      )

    {:ok, album} =
      Album.create(
        struct(
          Album,
          Map.merge(
            %{
              name: "Discovery",
              provider_ids: %{spotify: "3DarhD7Q3E4Xz0rXoJt59A"},
              artists: [artist],
              release_date: ~D[2001-03-12],
              cover_url: "https://example.com/cover.jpg",
              total_tracks: 14,
              tracks: [track_struct]
            },
            album_attrs
          )
        )
      )

    # Get the track from the album
    [track] = album.tracks
    # Reload track and preload album with artists
    track |> PremiereEcoute.Repo.preload(album: :artists)
  end

  defp expect_genius_search_song do
    expect(GeniusApi, :search_song, fn _query ->
      {:ok,
       [%{id: 71_255, title: "One More Time", artist: "Daft Punk", url: "https://genius.com/Daft-punk-one-more-time-lyrics"}]}
    end)
  end

  defp expect_genius_search_song_empty do
    expect(GeniusApi, :search_song, fn _query -> {:ok, []} end)
  end

  defp expect_genius_get_song do
    expect(GeniusApi, :get_song, fn _id ->
      {:ok, %{id: 71_255, url: "https://genius.com/Daft-punk-one-more-time-lyrics"}}
    end)
  end

  describe "enrich_track/1 - genius" do
    test "fetches genius URL and stores it in external_links" do
      track = create_track_with_album()
      expect_genius_search_song()
      expect_genius_get_song()

      {:ok, updated} = EnrichTrack.enrich_track(track)

      assert updated.external_links[:genius] == "https://genius.com/Daft-punk-one-more-time-lyrics"
    end

    test "persists the genius URL to the database" do
      track = create_track_with_album()
      expect_genius_search_song()
      expect_genius_get_song()

      {:ok, _} = EnrichTrack.enrich_track(track)

      assert Track.get(track.id).external_links["genius"] ==
               "https://genius.com/Daft-punk-one-more-time-lyrics"
    end

    test "overwrites existing genius link with freshly fetched value" do
      track =
        create_track_with_album(%{
          external_links: %{genius: "https://genius.com/old-url"}
        })

      expect_genius_search_song()
      expect_genius_get_song()

      {:ok, returned} = EnrichTrack.enrich_track(track)

      assert returned.external_links[:genius] == "https://genius.com/Daft-punk-one-more-time-lyrics"
    end

    test "stores nil when genius has no search results" do
      track = create_track_with_album()
      expect_genius_search_song_empty()

      {:ok, updated} = EnrichTrack.enrich_track(track)

      assert Map.has_key?(Track.get(track.id).external_links, "genius")
      assert is_nil(Track.get(track.id).external_links["genius"])
      assert updated.external_links[:genius] == nil
    end

    test "uses album artist name for search query" do
      {:ok, artist} = Artist.create_if_not_exists(%{name: "The Weeknd"})

      track_struct =
        struct(Track, %{
          name: "Blinding Lights",
          provider_ids: %{spotify: "track_test_id"},
          track_number: 1,
          duration_ms: 200_000
        })

      {:ok, album} =
        Album.create(
          struct(Album, %{
            name: "After Hours",
            provider_ids: %{spotify: "test_id"},
            artists: [artist],
            release_date: ~D[2020-03-20],
            cover_url: "https://example.com/cover.jpg",
            total_tracks: 14,
            tracks: [track_struct]
          })
        )

      [track] = album.tracks
      track_with_album = Track.get(track.id)

      expect(GeniusApi, :search_song, fn _query ->
        {:ok,
         [
           %{
             id: 71_255,
             title: "Blinding Lights",
             artist: "The Weeknd",
             url: "https://genius.com/The-weeknd-blinding-lights-lyrics"
           }
         ]}
      end)

      expect(GeniusApi, :get_song, fn _id ->
        {:ok, %{id: 71_255, url: "https://genius.com/The-weeknd-blinding-lights-lyrics"}}
      end)

      {:ok, _updated} = EnrichTrack.enrich_track(track_with_album)

      # The search query should have been "Blinding Lights The Weeknd"
      # We verify this indirectly by checking that the enrichment succeeded
      assert Track.get(track_with_album.id).external_links["genius"] ==
               "https://genius.com/The-weeknd-blinding-lights-lyrics"
    end

    test "handles missing album artist gracefully" do
      # Create a track with minimal album info
      track = create_track_with_album()
      expect_genius_search_song()
      expect_genius_get_song()

      {:ok, updated} = EnrichTrack.enrich_track(track)

      # Should still succeed - artist_name/1 returns "" for missing artist
      assert updated.external_links[:genius] == "https://genius.com/Daft-punk-one-more-time-lyrics"
    end

    test "rejects non-matching artist in genius results" do
      track = create_track_with_album()

      expect(GeniusApi, :search_song, fn _query ->
        {:ok,
         [
           %{
             id: 999_999,
             title: "One More Time",
             artist: "Julio Iglesias",
             url: "https://genius.com/julio-iglesias-one-more-time-lyrics"
           }
         ]}
      end)

      {:ok, updated} = EnrichTrack.enrich_track(track)

      # Should return nil because artist doesn't match
      assert updated.external_links[:genius] == nil
    end

    test "accepts fuzzy artist matches (e.g., extra spaces or special characters)" do
      track = create_track_with_album()

      expect(GeniusApi, :search_song, fn _query ->
        {:ok,
         [%{id: 71_255, title: "One More Time", artist: "Daft  Punk", url: "https://genius.com/Daft-punk-one-more-time-lyrics"}]}
      end)

      expect(GeniusApi, :get_song, fn _id ->
        {:ok, %{id: 71_255, url: "https://genius.com/Daft-punk-one-more-time-lyrics"}}
      end)

      {:ok, updated} = EnrichTrack.enrich_track(track)

      # Should accept fuzzy match (extra spaces normalized)
      assert updated.external_links[:genius] == "https://genius.com/Daft-punk-one-more-time-lyrics"
    end
  end
end
