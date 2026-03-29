defmodule PremiereEcoute.Discography.Workers.EnrichTrackWorkerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Apis.MusicMetadata.GeniusApi.Mock, as: GeniusApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Workers.EnrichTrackWorker

  defp create_track_fixture do
    {:ok, artist} = Artist.create_if_not_exists(%{name: "Daft Punk"})

    track_struct =
      struct(Track, %{
        name: "One More Time",
        provider_ids: %{spotify: "track001"},
        track_number: 1,
        duration_ms: 320_000
      })

    {:ok, album} =
      Album.create(
        struct(Album, %{
          name: "Discovery",
          provider_ids: %{spotify: "album001"},
          artists: [artist],
          release_date: ~D[2001-03-12],
          cover_url: "https://example.com/cover.jpg",
          total_tracks: 14,
          tracks: [track_struct]
        })
      )

    [track] = album.tracks
    Track.get(track.id)
  end

  defp expect_genius_success do
    expect(GeniusApi, :search_song, fn _query ->
      {:ok,
       [%{id: 71_255, title: "One More Time", artist: "Daft Punk", url: "https://genius.com/Daft-punk-one-more-time-lyrics"}]}
    end)

    expect(GeniusApi, :get_song, fn _id ->
      {:ok, %{id: 71_255, url: "https://genius.com/Daft-punk-one-more-time-lyrics"}}
    end)
  end

  describe "perform/1" do
    test "enriches a track and broadcasts the event" do
      track = create_track_fixture()
      expect_genius_success()

      assert :ok = perform_job(EnrichTrackWorker, %{"id" => track.id})

      enriched = Track.get(track.id)
      assert enriched.external_links["genius"] == "https://genius.com/Daft-punk-one-more-time-lyrics"
    end

    test "returns :error when track is not found" do
      assert {:error, :not_found} = perform_job(EnrichTrackWorker, %{"id" => 999_999})
    end
  end
end
