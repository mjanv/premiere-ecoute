defmodule PremiereEcoute.Radio.Workers.SyncRadioDiscographyWorkerTest do
  use PremiereEcoute.DataCase, async: true

  import Hammox

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Workers.EnrichDiscographyWorker
  alias PremiereEcoute.Radio
  alias PremiereEcoute.Radio.Workers.SyncRadioDiscographyWorker

  setup :verify_on_exit!

  @yesterday Date.add(Date.utc_today(), -1)

  defp insert_radio_track(spotify_id, date \\ @yesterday) do
    user = user_fixture()
    started_at = DateTime.new!(date, ~T[10:00:00], "Etc/UTC")

    Oban.Testing.with_testing_mode(:manual, fn ->
      Radio.insert_track(user.id, "spotify", %{
        provider_ids: %{spotify: spotify_id},
        name: "Some Track",
        artist: "Some Artist",
        started_at: started_at
      })
    end)
  end

  defp track_response(spotify_track_id, artist_spotify_id) do
    {:ok,
     %Album.Track{
       provider_ids: %{spotify: spotify_track_id},
       name: "Some Track",
       track_number: 1,
       duration_ms: 240_000,
       album_spotify_id: "some_album_id",
       artist_spotify_id: artist_spotify_id
     }}
  end

  describe "perform/1" do
    test "schedules EnrichDiscographyWorker for each unique artist from yesterday's radio tracks" do
      insert_radio_track("track_1")
      insert_radio_track("track_2")

      stub(SpotifyApi, :get_track, fn
        "track_1" -> track_response("track_1", "artist_a")
        "track_2" -> track_response("track_2", "artist_b")
      end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(SyncRadioDiscographyWorker, %{})

        assert_enqueued(worker: EnrichDiscographyWorker, args: %{"spotify_id" => "artist_a"})
        assert_enqueued(worker: EnrichDiscographyWorker, args: %{"spotify_id" => "artist_b"})
      end)
    end

    test "deduplicates artists when multiple tracks share the same artist" do
      insert_radio_track("track_1")
      insert_radio_track("track_2")

      stub(SpotifyApi, :get_track, fn
        "track_1" -> track_response("track_1", "artist_same")
        "track_2" -> track_response("track_2", "artist_same")
      end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(SyncRadioDiscographyWorker, %{})

        assert [_] = all_enqueued(worker: EnrichDiscographyWorker)
      end)
    end

    test "skips tracks already present in album_tracks" do
      insert_radio_track("known_track")

      {:ok, artist} = Artist.create_if_not_exists(%{name: "Known Artist"})
      {:ok, album} = Album.create(album_fixture(%{artists: [artist]}))

      Repo.insert!(%Album.Track{
        provider_ids: %{spotify: "known_track"},
        name: "Known Track",
        track_number: 1,
        duration_ms: 200_000,
        album_id: album.id
      })

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(SyncRadioDiscographyWorker, %{})
        assert [] = all_enqueued(worker: EnrichDiscographyWorker)
      end)
    end

    test "skips tracks where get_track returns a single (nil)" do
      insert_radio_track("single_track")

      stub(SpotifyApi, :get_track, fn "single_track" -> {:error, :no_track_found} end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(SyncRadioDiscographyWorker, %{})
        assert [] = all_enqueued(worker: EnrichDiscographyWorker)
      end)
    end

    test "ignores tracks from days other than yesterday" do
      insert_radio_track("old_track", Date.add(Date.utc_today(), -2))
      insert_radio_track("future_track", Date.utc_today())

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = perform_job(SyncRadioDiscographyWorker, %{})
        assert [] = all_enqueued(worker: EnrichDiscographyWorker)
      end)
    end

    test "returns ok when no radio tracks exist for yesterday" do
      assert :ok = perform_job(SyncRadioDiscographyWorker, %{})
    end
  end
end
