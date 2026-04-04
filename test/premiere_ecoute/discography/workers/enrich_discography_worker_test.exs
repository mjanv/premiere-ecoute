defmodule PremiereEcoute.Discography.Workers.EnrichDiscographyWorkerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Workers.EnrichAlbumWorker
  alias PremiereEcoute.Discography.Workers.EnrichArtistWorker
  alias PremiereEcoute.Discography.Workers.EnrichDiscographyWorker
  alias PremiereEcoute.Discography.Workers.EnrichTrackWorker

  defp album_fixture(spotify_id, name, track_count) do
    {:ok, artist} = Artist.create_if_not_exists(%{name: "Daft Punk"})

    tracks =
      Enum.map(1..track_count, fn i ->
        struct(Album.Track, %{
          provider_ids: %{spotify: "track#{i}"},
          name: "Track #{i}",
          track_number: i,
          duration_ms: 200_000
        })
      end)

    struct(Album, %{
      name: name,
      provider_ids: %{spotify: spotify_id},
      artists: [artist],
      release_date: ~D[2020-01-01],
      cover_url: "https://example.com/cover.jpg",
      total_tracks: track_count,
      tracks: tracks
    })
  end

  test "enqueues artist, album, and track enrichment jobs" do
    {:ok, artist} =
      Artist.create_if_not_exists(%{
        name: "Daft Punk",
        provider_ids: %{spotify: "spotify123"}
      })

    stub(SpotifyApi, :get_artist_albums, fn _ ->
      {:ok, [album_fixture("album1", "Discovery", 2), album_fixture("album2", "Homework", 1)]}
    end)

    stub(SpotifyApi, :get_album, fn id ->
      case id do
        "album1" -> {:ok, album_fixture("album1", "Discovery", 2)}
        "album2" -> {:ok, album_fixture("album2", "Homework", 1)}
      end
    end)

    Oban.Testing.with_testing_mode(:manual, fn ->
      assert :ok = EnrichDiscographyWorker.run(artist)

      # Artist enrichment job
      assert_enqueued(worker: EnrichArtistWorker, args: %{"id" => artist.id})

      # Album enrichment jobs (2 albums created)
      albums = Repo.all(Album) |> Repo.preload(:artists)

      for album <- albums do
        assert_enqueued(worker: EnrichAlbumWorker, args: %{"id" => album.id})
      end

      # Track enrichment jobs (3 tracks created: 2 + 1)
      tracks = Repo.all(Album.Track)

      for track <- tracks do
        assert_enqueued(worker: EnrichTrackWorker, args: %{"id" => track.id})
      end
    end)
  end

  test "returns error when artist not found" do
    assert {:error, :not_found} = EnrichDiscographyWorker.run(nil)
  end
end
