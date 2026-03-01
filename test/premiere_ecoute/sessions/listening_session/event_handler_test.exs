defmodule PremiereEcoute.Sessions.ListeningSession.EventHandlerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Sessions.ListeningSession.EventHandler
  alias PremiereEcoute.Sessions.ListeningSession.Events.NextTrackStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted
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
                        args: %{"action" => "send_promo_message", "user_id" => user.id},
                        scheduled_at: DateTime.add(DateTime.utc_now(), 60, :second)
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
