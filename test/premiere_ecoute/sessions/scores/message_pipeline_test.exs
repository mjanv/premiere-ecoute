defmodule PremiereEcoute.Sessions.Scores.MessagePipelineTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcouteCore.Cache

  @pipeline PremiereEcoute.Sessions.Scores.MessagePipeline

  setup do
    start_supervised(@pipeline)

    user = user_fixture(%{twitch: %{user_id: "1234"}})
    {:ok, album} = Album.create(album_fixture())
    {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id, status: :active})
    {:ok, session} = ListeningSession.next_track(session)

    Cache.put(:sessions, "1234", Map.take(session, [:id, :vote_options, :current_track_id]))

    {:ok, %{user: user, session: session}}
  end

  describe "publish/2 - MessageSent" do
    test "cast new votes", %{session: session} do
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

      :timer.sleep(100)

      votes = Vote.all(where: [session_id: session.id])

      for {{vote, message}, i} <- Enum.with_index(Enum.zip(votes, messages)) do
        assert %Vote{viewer_id: viewer_id, value: ^message, track_id: ^track_id, is_streamer: false} = vote
        assert viewer_id == "viewer#{i + 1}"
      end

      report = Report.get_by(session_id: session.id)

      assert %PremiereEcoute.Sessions.Retrospective.Report{
               polls: [],
               session_id: _,
               session_summary: %{
                 "unique_votes" => ^n,
                 "unique_voters" => ^n,
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
               votes: _
             } = report
    end

    test "does not cast votes from invalid messages", %{session: session} do
      messages = [
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "Hello", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "@user ok", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "5 :emoji:", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "11", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "-1", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer2", message: "Hello", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer2", message: "@user ok", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer2", message: "5 :emoji:", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer2", message: "11", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer2", message: "-1", is_streamer: false}
      ]

      for message <- messages do
        PremiereEcouteCore.publish(@pipeline, message)
      end

      :timer.sleep(500)

      assert Enum.empty?(Vote.all(where: [session_id: session.id]))
      assert is_nil(Report.get_by(session_id: session.id))
    end

    test "does not cast votes twice", %{session: session} do
      messages = [
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "0", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "1", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "2", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "3", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "4", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "5", is_streamer: false}
      ]

      for message <- messages do
        PremiereEcouteCore.publish(@pipeline, message)
      end

      :timer.sleep(150)

      [vote] = Vote.all(where: [session_id: session.id, viewer_id: "viewer1"])

      assert %Vote{value: "0"} = vote
    end
  end
end
