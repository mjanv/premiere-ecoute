defmodule PremiereEcoute.Collections.CollectionSession.EventHandlerTest do
  use PremiereEcoute.DataCase, async: true

  import Hammox

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Collections.CollectionSession.EventHandler
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionCompleted
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionStarted
  alias PremiereEcoute.Collections.CollectionSession.Events.TrackDecided
  alias PremiereEcoute.Collections.CollectionSession.Events.VoteWindowOpened
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Workers.EnrichDiscographyWorker

  setup :verify_on_exit!

  describe "dispatch/1 - TrackDecided" do
    test "schedules EnrichDiscographyWorker when a track is kept and not in discography" do
      user = user_fixture()
      session = collection_session_fixture(user)

      stub(SpotifyApi, :get_track, fn "track_new" ->
        {:ok,
         %Album.Track{
           provider_ids: %{spotify: "track_new"},
           name: "Some Track",
           track_number: 1,
           duration_ms: 200_000,
           album_spotify_id: "album_id",
           artist_spotify_id: "artist_spotify_id"
         }}
      end)

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%TrackDecided{
          session_id: session.id,
          user_id: user.id,
          track_id: "track_new",
          decision: :kept
        })

        assert_enqueued(worker: EnrichDiscographyWorker, args: %{"spotify_id" => "artist_spotify_id"})
      end)
    end

    test "does not schedule enrichment when track is already in discography" do
      user = user_fixture()
      session = collection_session_fixture(user)

      {:ok, artist} = PremiereEcoute.Discography.Artist.create_if_not_exists(%{name: "Known Artist"})
      {:ok, album} = Album.create(album_fixture(%{artists: [artist]}))

      Repo.insert!(%Album.Track{
        provider_ids: %{spotify: "track_known"},
        name: "Known Track",
        track_number: 1,
        duration_ms: 200_000,
        album_id: album.id
      })

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%TrackDecided{
          session_id: session.id,
          user_id: user.id,
          track_id: "track_known",
          decision: :kept
        })

        assert [] = all_enqueued(worker: EnrichDiscographyWorker)
      end)
    end

    test "does not schedule enrichment when decision is :rejected" do
      user = user_fixture()
      session = collection_session_fixture(user)

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%TrackDecided{
          session_id: session.id,
          user_id: user.id,
          track_id: "track_rejected",
          decision: :rejected
        })

        assert [] = all_enqueued(worker: EnrichDiscographyWorker)
      end)
    end

    test "does not schedule enrichment when decision is :skipped" do
      user = user_fixture()
      session = collection_session_fixture(user)

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%TrackDecided{
          session_id: session.id,
          user_id: user.id,
          track_id: "track_skipped",
          decision: :skipped
        })

        assert [] = all_enqueued(worker: EnrichDiscographyWorker)
      end)
    end
  end

  describe "dispatch/1 - CollectionSessionStarted" do
    test "broadcasts session_started and collection_started" do
      user = user_fixture()
      session = collection_session_fixture(user)

      PremiereEcoute.PubSub.subscribe("collection:#{session.id}")
      PremiereEcoute.PubSub.subscribe("playback:#{user.id}")

      EventHandler.dispatch(%CollectionSessionStarted{session_id: session.id, user_id: user.id})

      session_id = session.id
      assert_receive :session_started
      assert_receive {:collection_started, ^session_id}
    end
  end

  describe "dispatch/1 - VoteWindowOpened" do
    test "schedules close_vote worker and broadcasts vote_open" do
      user = user_fixture()
      session = collection_session_fixture(user, %{selection_mode: :viewer_vote, vote_duration: 30})

      PremiereEcoute.PubSub.subscribe("collection:#{session.id}")

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%VoteWindowOpened{
          session_id: session.id,
          user_id: user.id,
          track_id: "track1",
          duel_track_id: nil,
          selection_mode: :viewer_vote,
          vote_duration: 30
        })
      end)

      assert_receive :vote_open
    end
  end

  describe "dispatch/1 - CollectionSessionCompleted" do
    test "broadcasts session_completed and collection_completed" do
      user = user_fixture()
      session = collection_session_fixture(user)

      PremiereEcoute.PubSub.subscribe("collection:#{session.id}")

      EventHandler.dispatch(%CollectionSessionCompleted{session_id: session.id, user_id: user.id, kept_count: 5})

      assert_receive {:session_completed, 5}
    end
  end
end
