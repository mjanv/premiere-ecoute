defmodule PremiereEcoute.Sessions.Scores.EventHandlerTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Events.Chat.PollUpdated
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Poll
  alias PremiereEcoute.Sessions.Scores.Report
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcouteCore.EventBus

  @pipeline PremiereEcoute.Sessions.Scores.MessagePipeline

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
      n = 10
      track_id = session.current_track.id

      values = for _ <- 1..n, do: :rand.uniform(10)
      messages = Enum.map(values, &Integer.to_string/1)
      average = Float.round(Enum.sum(values) / length(values), 1)

      messages
      |> Enum.with_index()
      |> Enum.map(fn {m, i} ->
        %MessageSent{broadcaster_id: "1234", user_id: "viewer#{i + 1}", message: m, is_streamer: false}
      end)
      |> Enum.each(fn m -> PremiereEcouteCore.publish(@pipeline, m) end)

      :timer.sleep(500)

      votes = Vote.all(where: [session_id: session.id])

      for {{vote, message}, i} <- Enum.with_index(Enum.zip(votes, messages)) do
        assert %Vote{viewer_id: viewer_id, value: ^message, track_id: ^track_id, is_streamer: false} = vote
        assert viewer_id == "viewer#{i + 1}"
      end

      report = Report.get_by(session_id: session.id)

      assert %PremiereEcoute.Sessions.Scores.Report{
               unique_votes: ^n,
               polls: [],
               session_id: _,
               session_summary: %{
                 "streamer_score" => +0.0,
                 "tracks_rated" => 1,
                 "viewer_score" => ^average
               },
               track_summaries: [
                 %{
                   "unique_votes" => ^n,
                   "poll_count" => 0,
                   "streamer_score" => +0.0,
                   "unique_voters" => ^n,
                   "viewer_score" => ^average
                 }
               ],
               unique_voters: ^n,
               votes: _
             } = report
    end

    test "does not cast vote from invalid messages", %{session: session} do
      messages = [
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "Hello", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "@user ok", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer2", message: "11", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer2", message: "-1", is_streamer: false}
      ]

      for message <- messages do
        PremiereEcouteCore.publish(@pipeline, message)
      end

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
