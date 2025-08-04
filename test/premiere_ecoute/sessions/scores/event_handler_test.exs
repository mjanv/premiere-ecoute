defmodule PremiereEcoute.Sessions.Scores.EventHandlerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Core.EventBus
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Events.MessageSent
  alias PremiereEcoute.Sessions.Scores.Events.PollUpdated
  alias PremiereEcoute.Sessions.Scores.Poll
  alias PremiereEcoute.Sessions.Scores.Report
  alias PremiereEcoute.Sessions.Scores.Vote

  setup do
    user = user_fixture(%{twitch: %{user_id: "1234"}})
    {:ok, album} = Album.create(album_fixture())

    {:ok, session} =
      ListeningSession.create(%{user_id: user.id, album_id: album.id, status: :active})

    {:ok, session} = ListeningSession.next_track(session)

    {:ok, %{user: user, session: session}}
  end

  describe "dispatch/1 - MessageSent" do
    test "cast a new vote", %{session: session} do
      track_id = session.current_track.id

      EventBus.dispatch(%MessageSent{
        broadcaster_id: "1234",
        user_id: "viewer1",
        message: "5",
        is_streamer: false
      })

      EventBus.dispatch(%MessageSent{
        broadcaster_id: "1234",
        user_id: "viewer2",
        message: "0",
        is_streamer: false
      })

      [%Vote{} = vote1, %Vote{} = vote2] = Vote.all(where: [session_id: session.id])

      assert %Vote{viewer_id: "viewer1", value: "5", track_id: ^track_id, is_streamer: false} =
               vote1

      assert %Vote{viewer_id: "viewer2", value: "0", track_id: ^track_id, is_streamer: false} =
               vote2

      report = Report.get_by(session_id: session.id)

      assert %PremiereEcoute.Sessions.Scores.Report{
               unique_votes: 2,
               polls: [],
               session_id: _,
               session_summary: %{
                 "streamer_score" => +0.0,
                 "tracks_rated" => 1,
                 "viewer_score" => 2.5
               },
               track_summaries: [
                 %{
                   "unique_votes" => 2,
                   "poll_count" => 0,
                   "streamer_score" => +0.0,
                   "unique_voters" => 2,
                   "viewer_score" => 2.5
                 }
               ],
               unique_voters: 2,
               votes: _
             } = report
    end

    test "does not cast vote from invalid messages", %{session: session} do
      EventBus.dispatch(%MessageSent{
        broadcaster_id: "1234",
        user_id: "viewer1",
        message: "Hello",
        is_streamer: false
      })

      EventBus.dispatch(%MessageSent{
        broadcaster_id: "1234",
        user_id: "viewer1",
        message: "@user ok",
        is_streamer: false
      })

      EventBus.dispatch(%MessageSent{
        broadcaster_id: "1234",
        user_id: "viewer2",
        message: "11",
        is_streamer: false
      })

      EventBus.dispatch(%MessageSent{
        broadcaster_id: "1234",
        user_id: "viewer2",
        message: "-1",
        is_streamer: false
      })

      assert Enum.empty?(Vote.all(where: [session_id: session.id]))
      assert is_nil(Report.get_by(session_id: session.id))
    end
  end

  describe "dispatch/1 - PollUpdated" do
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

      EventBus.dispatch(%PollUpdated{id: "poll1", votes: %{"A" => 5, "B" => 7}})

      [%Poll{} = poll] = Poll.all(where: [session_id: session.id])

      assert %Poll{
               poll_id: "poll1",
               title: "Question ?",
               total_votes: 12,
               votes: %{"A" => 5, "B" => 7}
             } = poll
    end

    test "does not update an unknown poll", %{session: session} do
      EventBus.dispatch(%PollUpdated{id: "poll2", votes: %{"A" => 5, "B" => 7}})

      assert Enum.empty?(Poll.all(where: [session_id: session.id]))
    end
  end
end
