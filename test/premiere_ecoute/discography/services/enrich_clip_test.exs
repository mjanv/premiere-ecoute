defmodule PremiereEcoute.Discography.Services.EnrichClipTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.Video.YoutubeApi.Mock, as: YoutubeApi
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Services.EnrichClip
  alias PremiereEcoute.Discography.Single

  defp expect_youtube_video(attrs \\ %{}) do
    video =
      Map.merge(
        %{
          id: "abc123",
          title: "One More Time (Official Video)",
          channel_title: "Daft Punk",
          duration: "PT5M20S",
          thumbnail_url: "https://i.ytimg.com/vi/abc123/maxresdefault.jpg"
        },
        attrs
      )

    expect(YoutubeApi, :get_video, fn "abc123" -> {:ok, video} end)
  end

  describe "resolve_single/1" do
    test "resolves to the matching Spotify single when the channel matches the artist" do
      expect_youtube_video()

      {:ok, artist} = Artist.create_if_not_exists(%{name: "Daft Punk"})

      candidate =
        %Single{
          provider_ids: %{spotify: "spotify_track_1"},
          name: "One More Time",
          artists: [artist],
          duration_ms: 320_000,
          cover_url: "https://example.com/cover.jpg"
        }
        |> Single.put_artist()

      expect(SpotifyApi, :search_singles, fn _query -> {:ok, [candidate]} end)

      {:ok, single, thumbnail_url} = EnrichClip.resolve_single("abc123")

      assert single.name == "One More Time"
      assert single.provider_ids.spotify == "spotify_track_1"
      assert single.provider_ids.youtube == "abc123"
      assert single.artist.name == "Daft Punk"
      assert thumbnail_url == "https://i.ytimg.com/vi/abc123/maxresdefault.jpg"
    end

    test "returns an error when no Spotify candidate matches the channel" do
      expect_youtube_video(%{channel_title: "Some Random Reaction Channel"})

      {:ok, artist} = Artist.create_if_not_exists(%{name: "Daft Punk"})

      candidate =
        %Single{
          provider_ids: %{spotify: "spotify_track_1"},
          name: "One More Time",
          artists: [artist],
          duration_ms: 320_000,
          cover_url: "https://example.com/cover.jpg"
        }
        |> Single.put_artist()

      expect(SpotifyApi, :search_singles, fn _query -> {:ok, [candidate]} end)

      assert {:error, :no_match} = EnrichClip.resolve_single("abc123")
    end

    test "returns an error when Spotify search returns no candidates" do
      expect_youtube_video()
      expect(SpotifyApi, :search_singles, fn _query -> {:ok, []} end)

      assert {:error, :no_match} = EnrichClip.resolve_single("abc123")
    end

    test "safely excludes a candidate with no artists instead of crashing" do
      expect_youtube_video()

      {:ok, artist} = Artist.create_if_not_exists(%{name: "Daft Punk"})

      no_artist_candidate = %Single{
        provider_ids: %{spotify: "spotify_track_no_artist"},
        name: "One More Time",
        artists: [],
        duration_ms: 320_000,
        cover_url: "https://example.com/cover.jpg"
      }

      matching_candidate =
        %Single{
          provider_ids: %{spotify: "spotify_track_1"},
          name: "One More Time",
          artists: [artist],
          duration_ms: 320_000,
          cover_url: "https://example.com/cover.jpg"
        }
        |> Single.put_artist()

      expect(SpotifyApi, :search_singles, fn _query -> {:ok, [no_artist_candidate, matching_candidate]} end)

      {:ok, single, _thumbnail_url} = EnrichClip.resolve_single("abc123")

      assert single.provider_ids.spotify == "spotify_track_1"
    end

    test "returns an error when every candidate has no artists" do
      expect_youtube_video()

      no_artist_candidate = %Single{
        provider_ids: %{spotify: "spotify_track_no_artist"},
        name: "One More Time",
        artists: [],
        duration_ms: 320_000,
        cover_url: "https://example.com/cover.jpg"
      }

      expect(SpotifyApi, :search_singles, fn _query -> {:ok, [no_artist_candidate]} end)

      assert {:error, :no_match} = EnrichClip.resolve_single("abc123")
    end

    test "returns the underlying error when the Spotify search itself fails" do
      expect_youtube_video()
      expect(SpotifyApi, :search_singles, fn _query -> {:error, :timeout} end)

      assert {:error, :timeout} = EnrichClip.resolve_single("abc123")
    end

    test "returns the underlying error when the YouTube video lookup fails" do
      expect(YoutubeApi, :get_video, fn "abc123" -> {:error, :not_found} end)

      assert {:error, :not_found} = EnrichClip.resolve_single("abc123")
    end

    test "reuses an existing Single already created from the same Spotify track" do
      {:ok, artist} = Artist.create_if_not_exists(%{name: "Daft Punk"})

      {:ok, existing} =
        Single.create(%Single{
          provider_ids: %{spotify: "spotify_track_1"},
          name: "One More Time",
          artists: [artist],
          duration_ms: 320_000,
          cover_url: "https://example.com/cover.jpg"
        })

      expect_youtube_video()

      candidate =
        %Single{
          provider_ids: %{spotify: "spotify_track_1"},
          name: "One More Time",
          artists: [artist],
          duration_ms: 320_000,
          cover_url: "https://example.com/cover.jpg"
        }
        |> Single.put_artist()

      expect(SpotifyApi, :search_singles, fn _query -> {:ok, [candidate]} end)

      {:ok, single, _thumbnail_url} = EnrichClip.resolve_single("abc123")

      assert single.id == existing.id
      assert single.provider_ids.youtube == "abc123"
      assert single.provider_ids.spotify == "spotify_track_1"
    end

    test "skips the Spotify search entirely when this video was already resolved before" do
      {:ok, artist} = Artist.create_if_not_exists(%{name: "Daft Punk"})

      candidate =
        %Single{
          provider_ids: %{spotify: "spotify_track_1"},
          name: "One More Time",
          artists: [artist],
          duration_ms: 320_000,
          cover_url: "https://example.com/cover.jpg"
        }
        |> Single.put_artist()

      expect_youtube_video()
      expect(SpotifyApi, :search_singles, fn _query -> {:ok, [candidate]} end)

      {:ok, first_single, _thumbnail_url} = EnrichClip.resolve_single("abc123")

      expect_youtube_video()

      {:ok, second_single, _thumbnail_url} = EnrichClip.resolve_single("abc123")

      assert second_single.id == first_single.id
      assert second_single.provider_ids.youtube == "abc123"
    end
  end
end
