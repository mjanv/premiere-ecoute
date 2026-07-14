defmodule PremiereEcoute.Sessions.ListeningSession.EventHandlerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Sessions.ListeningSession.EventHandler
  alias PremiereEcoute.Sessions.ListeningSession.Events.NextTrackStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionPrepared
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted
  alias PremiereEcoute.Sessions.ListeningSession.Workers.MissedSessionNotificationWorker
  alias PremiereEcoute.Sessions.ListeningSessionWorker

  @cooldown Application.compile_env(:premiere_ecoute, PremiereEcoute.Sessions)[:vote_cooldown]

  describe "dispatch/1 - SessionStarted :track" do
    test "schedules open_track immediately and promo message, broadcasts session_started" do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%SessionStarted{
          source: :track,
          session_id: session.id,
          user_id: user.id
        })

        assert_enqueued worker: ListeningSessionWorker,
                        args: %{"action" => "open_track", "session_id" => session.id},
                        scheduled_at: DateTime.add(DateTime.utc_now(), 0, :second)

        assert_enqueued worker: ListeningSessionWorker,
                        args: %{"action" => "send_instructions", "user_id" => user.id},
                        scheduled_at: DateTime.add(DateTime.utc_now(), 15, :second)

        assert_enqueued worker: ListeningSessionWorker,
                        args: %{"action" => "send_promo_message", "user_id" => user.id},
                        scheduled_at: DateTime.add(DateTime.utc_now(), 30, :second)
      end)
    end
  end

  describe "dispatch/1 - SessionPrepared :clip" do
    test "broadcasts session_prepared on the user's playback topic" do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :preparing})

      PremiereEcoute.PubSub.subscribe("playback:#{user.id}")

      EventHandler.dispatch(%SessionPrepared{
        source: :clip,
        session_id: session.id,
        user_id: user.id
      })

      assert_receive {:session_prepared, session_id}
      assert session_id == session.id
    end
  end

  describe "dispatch/1 - SessionStarted :clip" do
    test "schedules open_clip immediately and promo message, broadcasts session_started" do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%SessionStarted{
          source: :clip,
          session_id: session.id,
          user_id: user.id
        })

        assert_enqueued worker: ListeningSessionWorker,
                        args: %{"action" => "open_clip", "session_id" => session.id},
                        scheduled_at: DateTime.add(DateTime.utc_now(), 0, :second)

        assert_enqueued worker: ListeningSessionWorker,
                        args: %{"action" => "send_instructions", "user_id" => user.id},
                        scheduled_at: DateTime.add(DateTime.utc_now(), 15, :second)

        assert_enqueued worker: ListeningSessionWorker,
                        args: %{"action" => "send_promo_message", "user_id" => user.id},
                        scheduled_at: DateTime.add(DateTime.utc_now(), 30, :second)
      end)
    end

    test "broadcasts session_started on the user's playback topic" do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})

      PremiereEcoute.PubSub.subscribe("playback:#{user.id}")

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%SessionStarted{
          source: :clip,
          session_id: session.id,
          user_id: user.id
        })
      end)

      assert_receive {:session_started, session_id}
      assert session_id == session.id
    end
  end

  describe "dispatch/1 - SessionStarted :free" do
    test "schedules promo message and broadcasts session_started" do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%SessionStarted{
          source: :free,
          session_id: session.id,
          user_id: user.id
        })

        assert_enqueued worker: ListeningSessionWorker,
                        args: %{"action" => "send_promo_message", "user_id" => user.id},
                        scheduled_at: DateTime.add(DateTime.utc_now(), 60, :second)
      end)
    end
  end

  describe "dispatch/1 - SessionStopped" do
    test "schedules send_session_link job 20 seconds after session stops" do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped{
          session_id: session.id,
          user_id: user.id
        })

        assert_enqueued worker: ListeningSessionWorker,
                        args: %{"action" => "send_session_link", "session_id" => session.id, "user_id" => user.id},
                        scheduled_at: DateTime.add(DateTime.utc_now(), 20, :second)
      end)
    end

    test "enqueues a missed-session notification job for each follower who did not vote" do
      streamer = user_fixture(%{role: :streamer})
      follower = user_fixture(%{role: :viewer, twitch: %{user_id: "twitch_viewer_handler"}})
      {:ok, _} = Accounts.follow(follower, streamer)
      session = session_fixture(%{user_id: streamer.id, status: :active})

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped{
          session_id: session.id,
          user_id: streamer.id
        })

        assert_enqueued worker: MissedSessionNotificationWorker,
                        args: %{"session_id" => session.id, "user_id" => follower.id}
      end)
    end
  end

  describe "dispatch/1 - NextTrackStarted album" do
    test "schedules open_album after cooldown for a normal-length track" do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})
      track = %{duration_ms: @cooldown * 1000 * 2 + 1}

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%NextTrackStarted{
          source: :album,
          session_id: session.id,
          user_id: user.id,
          track: track
        })

        assert_enqueued worker: ListeningSessionWorker,
                        args: %{"action" => "open_album", "session_id" => session.id},
                        scheduled_at: DateTime.add(DateTime.utc_now(), @cooldown, :second)
      end)
    end

    test "schedules open_album after 5 seconds for a short track" do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})
      track = %{duration_ms: @cooldown * 1000 * 2}

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%NextTrackStarted{
          source: :album,
          session_id: session.id,
          user_id: user.id,
          track: track
        })

        assert_enqueued worker: ListeningSessionWorker,
                        args: %{"action" => "open_album", "session_id" => session.id},
                        scheduled_at: DateTime.add(DateTime.utc_now(), 5, :second)
      end)
    end
  end
end
