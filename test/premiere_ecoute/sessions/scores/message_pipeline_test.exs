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

      :timer.sleep(150)

      votes = Vote.all(where: [session_id: session.id])

      assert length(votes) == n

      for {message, i} <- Enum.with_index(messages) do
        viewer_id = "viewer#{i + 1}"
        vote = Enum.find(votes, fn v -> v.viewer_id == viewer_id end)
        assert %Vote{viewer_id: ^viewer_id, value: ^message, track_id: ^track_id, is_streamer: false} = vote
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

    test "updates vote when viewer votes again", %{session: session} do
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

      assert %Vote{value: "5"} = vote
    end

    test "updates existing vote when viewer votes again for same track", %{session: session} do
      track_id = session.current_track.id

      messages = [
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "5", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "8", is_streamer: false}
      ]

      for message <- messages do
        PremiereEcouteCore.publish(@pipeline, message)
      end

      :timer.sleep(150)

      votes = Vote.all(where: [session_id: session.id, viewer_id: "viewer1"])

      assert length(votes) == 1
      assert %Vote{value: "8", track_id: ^track_id} = hd(votes)

      report = Report.get_by(session_id: session.id)

      assert %PremiereEcoute.Sessions.Retrospective.Report{
               session_summary: %{
                 "unique_votes" => 1,
                 "unique_voters" => 1,
                 "viewer_score" => 8.0
               }
             } = report
    end

    test "handles concurrent vote updates from multiple viewers", %{session: session} do
      track_id = session.current_track.id

      messages = [
        # viewer1: votes 3 times (should end up with "7")
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "3", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "5", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "7", is_streamer: false},
        # viewer2: votes 2 times (should end up with "9")
        %MessageSent{broadcaster_id: "1234", user_id: "viewer2", message: "4", is_streamer: false},
        %MessageSent{broadcaster_id: "1234", user_id: "viewer2", message: "9", is_streamer: false},
        # viewer3: votes once (should end up with "6")
        %MessageSent{broadcaster_id: "1234", user_id: "viewer3", message: "6", is_streamer: false},
        # viewer4: votes once (should end up with "2")
        %MessageSent{broadcaster_id: "1234", user_id: "viewer4", message: "2", is_streamer: false}
      ]

      for message <- messages do
        PremiereEcouteCore.publish(@pipeline, message)
      end

      :timer.sleep(150)

      votes = Vote.all(where: [session_id: session.id])

      assert length(votes) == 4

      vote1 = Enum.find(votes, fn v -> v.viewer_id == "viewer1" end)
      vote2 = Enum.find(votes, fn v -> v.viewer_id == "viewer2" end)
      vote3 = Enum.find(votes, fn v -> v.viewer_id == "viewer3" end)
      vote4 = Enum.find(votes, fn v -> v.viewer_id == "viewer4" end)

      assert %Vote{value: "7", track_id: ^track_id} = vote1
      assert %Vote{value: "9", track_id: ^track_id} = vote2
      assert %Vote{value: "6", track_id: ^track_id} = vote3
      assert %Vote{value: "2", track_id: ^track_id} = vote4

      report = Report.get_by(session_id: session.id)

      # Average: (7 + 9 + 6 + 2) / 4 = 6.0
      assert %PremiereEcoute.Sessions.Retrospective.Report{
               session_summary: %{
                 "unique_votes" => 4,
                 "unique_voters" => 4,
                 "viewer_score" => 6.0
               }
             } = report
    end

    test "updates vote preserves updated_at timestamp", %{session: session} do
      messages = [
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "5", is_streamer: false}
      ]

      for message <- messages do
        PremiereEcouteCore.publish(@pipeline, message)
      end

      :timer.sleep(150)

      [first_vote] = Vote.all(where: [session_id: session.id, viewer_id: "viewer1"])
      first_updated_at = first_vote.updated_at

      :timer.sleep(1000)

      updated_messages = [
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "8", is_streamer: false}
      ]

      for message <- updated_messages do
        PremiereEcouteCore.publish(@pipeline, message)
      end

      :timer.sleep(150)

      [updated_vote] = Vote.all(where: [session_id: session.id, viewer_id: "viewer1"])

      assert %Vote{value: "8"} = updated_vote
      assert DateTime.compare(updated_vote.updated_at, first_updated_at) == :gt
    end

    test "vote updates are isolated per track", %{session: session} do
      track1_id = session.current_track.id

      messages_track1 = [
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "5", is_streamer: false}
      ]

      for message <- messages_track1 do
        PremiereEcouteCore.publish(@pipeline, message)
      end

      :timer.sleep(150)

      {:ok, session} = ListeningSession.next_track(session)
      track2_id = session.current_track.id

      Cache.put(:sessions, "1234", Map.take(session, [:id, :vote_options, :current_track_id]))

      messages_track2 = [
        %MessageSent{broadcaster_id: "1234", user_id: "viewer1", message: "8", is_streamer: false}
      ]

      for message <- messages_track2 do
        PremiereEcouteCore.publish(@pipeline, message)
      end

      :timer.sleep(150)

      votes = Vote.all(where: [session_id: session.id, viewer_id: "viewer1"])

      assert length(votes) == 2

      vote1 = Enum.find(votes, fn v -> v.track_id == track1_id end)
      vote2 = Enum.find(votes, fn v -> v.track_id == track2_id end)

      assert %Vote{value: "5", track_id: ^track1_id} = vote1
      assert %Vote{value: "8", track_id: ^track2_id} = vote2
    end
  end
end
