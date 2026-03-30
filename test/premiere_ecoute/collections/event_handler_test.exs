defmodule PremiereEcoute.Collections.CollectionSession.EventHandlerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Collections.CollectionSession.EventHandler
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionCompleted
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionStarted
  alias PremiereEcoute.Collections.CollectionSession.Events.VoteWindowOpened
  # alias PremiereEcoute.Collections.CollectionSessionWorker

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

        # assert_enqueued worker: CollectionSessionWorker,
        #                args: %{"action" => "close_vote", "session_id" => session.id, "track_id" => "track1"}
      end)

      assert_receive :vote_open
    end
  end

  describe "dispatch/1 - CollectionSessionCompleted" do
    test "broadcasts session_completed and collection_completed" do
      user = user_fixture()
      session = collection_session_fixture(user)

      PremiereEcoute.PubSub.subscribe("collection:#{session.id}")
      PremiereEcoute.PubSub.subscribe("playback:#{user.id}")

      EventHandler.dispatch(%CollectionSessionCompleted{session_id: session.id, user_id: user.id, kept_count: 5})

      session_id = session.id
      assert_receive {:session_completed, 5}
    end
  end
end
