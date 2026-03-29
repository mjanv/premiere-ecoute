defmodule PremiereEcoute.Sessions.Scores.PollPipelineTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Events.Chat.PollStarted
  alias PremiereEcoute.Events.Chat.PollUpdated
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Poll

  @pipeline PremiereEcoute.Sessions.Scores.PollPipeline

  setup do
    start_supervised(@pipeline)

    user = user_fixture(%{twitch: %{user_id: "1234"}})
    {:ok, album} = Album.create(album_fixture())

    {:ok, session} =
      ListeningSession.create(%{user_id: user.id, album_id: album.id, status: :active})

    {:ok, session} = ListeningSession.next_track(session)

    {:ok, %{user: user, session: session}}
  end

  describe "publish/2 - PollStarted" do
    test "creates a poll with zero votes when session is active", %{session: session} do
      broadcaster_id = session.user.twitch.user_id

      PremiereEcouteCore.Cache.put(
        :sessions,
        broadcaster_id,
        %{id: session.id, current_track_id: session.current_track.id, vote_options: ["A", "B"]}
      )

      PremiereEcouteCore.publish(@pipeline, %PollStarted{
        id: "poll-start-1",
        title: "Which one?",
        broadcaster_id: broadcaster_id,
        votes: %{"A" => 0, "B" => 0}
      })

      :timer.sleep(100)

      [%Poll{} = poll] = Poll.all(where: [session_id: session.id])

      assert %Poll{
               poll_id: "poll-start-1",
               title: "Which one?",
               total_votes: 0,
               votes: %{"A" => 0, "B" => 0}
             } = poll
    end

    test "does nothing when no active session in cache", %{session: session} do
      PremiereEcouteCore.publish(@pipeline, %PollStarted{
        id: "poll-start-2",
        title: "Which one?",
        broadcaster_id: "unknown-broadcaster",
        votes: %{"A" => 0, "B" => 0}
      })

      :timer.sleep(100)

      assert Enum.empty?(Poll.all(where: [session_id: session.id]))
    end
  end

  describe "publish/2 - PollUpdated" do
    test "update an existing poll", %{session: session} do
      {:ok, _} =
        Poll.create(%Poll{
          poll_id: "poll1",
          session_id: session.id,
          track_id: session.current_track.id,
          title: "Question ?",
          total_votes: 0,
          votes: %{"A" => 0, "B" => 0}
        })

      PremiereEcouteCore.publish(@pipeline, %PollUpdated{id: "poll1", votes: %{"A" => 5, "B" => 7}})

      :timer.sleep(100)

      [%Poll{} = poll] = Poll.all(where: [session_id: session.id])

      assert %Poll{
               poll_id: "poll1",
               title: "Question ?",
               total_votes: 12,
               votes: %{"A" => 5, "B" => 7}
             } = poll
    end

    test "does not update an unknown poll", %{session: session} do
      PremiereEcouteCore.publish(@pipeline, %PollUpdated{id: "poll2", votes: %{"A" => 5, "B" => 7}})

      assert Enum.empty?(Poll.all(where: [session_id: session.id]))
    end
  end
end
