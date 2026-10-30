defmodule PremiereEcoute.Sessions.Scores.AlbumVoteTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Retrospective.VoteTrends
  alias PremiereEcoute.Sessions.Scores.MessagePipeline
  alias PremiereEcoute.Sessions.Scores.PostSessionVote
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcouteCore.Cache

  @album_options %{"votes" => 0, "scores" => 0, "next_track" => 0, "vote_scope" => "album"}

  setup do
    user = user_fixture(%{twitch: %{user_id: "1234"}})
    {:ok, album} = Album.create(album_fixture())

    {:ok, session} =
      ListeningSession.create(%{user_id: user.id, album_id: album.id, status: :active, options: @album_options})

    {:ok, %{user: user, album: album, session: session}}
  end

  defp text_scale_session(user, album, options) do
    {:ok, session} =
      ListeningSession.create(%{
        user_id: user.id,
        album_id: album.id,
        status: :active,
        vote_options: ["smash", "pass"],
        options: options
      })

    session
  end

  defp album_vote(session, viewer_id, value, is_streamer \\ false) do
    %Vote{viewer_id: viewer_id, session_id: session.id, scope: :album, value: value, is_streamer: is_streamer}
  end

  describe "ListeningSession.album_vote?/1" do
    test "is true only when the session vote scope is album", %{session: session} do
      assert ListeningSession.album_vote?(session)
      refute ListeningSession.album_vote?(%{session | options: %{"votes" => 0}})
      refute ListeningSession.album_vote?(%{session | options: %{"vote_scope" => "track"}})
    end
  end

  describe "Vote - album scope" do
    test "votes default to the track scope", %{session: session, album: album} do
      {:ok, vote} =
        Vote.create(%Vote{viewer_id: "v1", session_id: session.id, track_id: hd(album.tracks).id, value: "5"})

      assert vote.scope == :track
    end

    test "stores an album vote without track", %{session: session} do
      assert {:ok, %Vote{scope: :album, track_id: nil, value: "7"}} = Vote.create(album_vote(session, "v1", "7"))
    end

    test "rejects a second album vote of the same viewer on the same session", %{session: session} do
      {:ok, _} = Vote.create(album_vote(session, "v1", "7"))

      assert {:error, %Ecto.Changeset{}} = Vote.create(album_vote(session, "v1", "3"))
      assert [%Vote{value: "7"}] = Vote.all(where: [session_id: session.id])
    end

    test "keeps only the first album vote on bulk insert", %{session: session} do
      now = DateTime.truncate(DateTime.utc_now(), :second)

      rows =
        for value <- ["7", "3"] do
          %{
            viewer_id: "v1",
            session_id: session.id,
            track_id: nil,
            scope: :album,
            value: value,
            is_streamer: false,
            inserted_at: now,
            updated_at: now
          }
        end

      Vote.create_all(rows, on_conflict: :nothing)

      assert [%Vote{value: "7"}] = Vote.all(where: [session_id: session.id])
    end

    test "rejects a track vote without track", %{session: session} do
      assert {:error, %Ecto.Changeset{}} =
               Vote.create(%Vote{viewer_id: "v1", session_id: session.id, scope: :track, value: "7"})
    end
  end

  describe "MessagePipeline - album scope" do
    setup %{session: session} do
      start_supervised(MessagePipeline)

      Cache.put(:sessions, "1234", %{
        id: session.id,
        vote_options: session.vote_options,
        current_track_id: nil,
        vote_scope: :album
      })

      on_exit(fn -> Cache.del(:sessions, "1234") end)
      :ok
    end

    test "casts an album vote even when no track is playing", %{session: session} do
      PremiereEcouteCore.publish(MessagePipeline, %MessageSent{
        broadcaster_id: "1234",
        user_id: "viewer1",
        message: "8",
        is_streamer: false
      })

      :timer.sleep(100)

      assert [%Vote{viewer_id: "viewer1", scope: :album, track_id: nil, value: "8"}] =
               Vote.all(where: [session_id: session.id])
    end

    test "keeps the first vote of a viewer and ignores later ones", %{session: session} do
      for message <- ["8", "2"] do
        PremiereEcouteCore.publish(MessagePipeline, %MessageSent{
          broadcaster_id: "1234",
          user_id: "viewer1",
          message: message,
          is_streamer: false
        })

        :timer.sleep(100)
      end

      assert [%Vote{value: "8"}] = Vote.all(where: [session_id: session.id])
    end

    test "broadcasts the album summary", %{session: session} do
      PremiereEcoute.PubSub.subscribe("session:#{session.id}")

      PremiereEcouteCore.publish(MessagePipeline, %MessageSent{
        broadcaster_id: "1234",
        user_id: "viewer1",
        message: "6",
        is_streamer: false
      })

      assert_receive {:session_summary, %{viewer_score: 6.0, unique_votes: 1}}, 1_000
    end
  end

  describe "Report.generate/1 - album scope" do
    test "computes the session score from album votes only", %{session: session} do
      {:ok, _} = Vote.create(album_vote(session, "v1", "8"))
      {:ok, _} = Vote.create(album_vote(session, "v2", "6"))
      {:ok, _} = Vote.create(album_vote(session, "streamer", "9", true))

      {:ok, report} = Report.generate(session)

      assert report.track_summaries == []

      assert %{viewer_score: 7.0, streamer_score: 9.0, unique_votes: 3, unique_voters: 3, tracks_rated: 0} =
               report.session_summary
    end

    test "computes the most frequent value for text vote options", %{user: user, album: album} do
      {:ok, session} =
        ListeningSession.create(%{
          user_id: user.id,
          album_id: album.id,
          status: :active,
          vote_options: ["smash", "pass"],
          options: @album_options
        })

      {:ok, _} = Vote.create(album_vote(session, "v1", "smash"))
      {:ok, _} = Vote.create(album_vote(session, "v2", "smash"))
      {:ok, _} = Vote.create(album_vote(session, "v3", "pass"))

      {:ok, report} = Report.generate(session)

      assert %{viewer_score: "smash", streamer_score: nil} = report.session_summary
    end

    test "rounds the session score to one decimal", %{session: session} do
      for {viewer, value} <- [{"v1", "8"}, {"v2", "7"}, {"v3", "7"}] do
        {:ok, _} = Vote.create(album_vote(session, viewer, value))
      end

      {:ok, report} = Report.generate(session)

      assert report.session_summary.viewer_score == 7.3
    end

    test "returns even on a tie for text vote options", %{user: user, album: album} do
      session = text_scale_session(user, album, @album_options)

      {:ok, _} = Vote.create(album_vote(session, "v1", "smash"))
      {:ok, _} = Vote.create(album_vote(session, "v2", "pass"))

      {:ok, report} = Report.generate(session)

      assert report.session_summary.viewer_score == "even"
    end

    test "returns empty scores without votes", %{session: session} do
      {:ok, report} = Report.generate(session)

      assert %{viewer_score: nil, streamer_score: nil, unique_votes: 0, unique_voters: 0, tracks_rated: 0} =
               report.session_summary
    end

    test "returns an empty viewer score when only the streamer voted", %{session: session} do
      {:ok, _} = Vote.create(album_vote(session, "streamer", "9", true))

      {:ok, report} = Report.generate(session)

      assert %{viewer_score: nil, streamer_score: 9.0} = report.session_summary
    end

    test "uses album votes for the session score when track votes also exist", %{session: session, album: album} do
      track = hd(album.tracks)

      {:ok, _} = Vote.create(%Vote{viewer_id: "v1", session_id: session.id, track_id: track.id, value: "2"})
      {:ok, _} = Vote.create(album_vote(session, "v1", "8"))
      {:ok, _} = Vote.create(album_vote(session, "v2", "9"))

      {:ok, report} = Report.generate(session)

      assert report.session_summary.viewer_score == 8.5
      assert [%{track_id: track_id, viewer_score: 2.0}] = report.track_summaries
      assert track_id == track.id
    end
  end

  describe "MessagePipeline - text vote options" do
    setup do
      start_supervised(MessagePipeline)
      on_exit(fn -> Cache.del(:sessions, "5678") end)
      :ok
    end

    test "broadcasts the album summary for a text vote scale", %{user: user, album: album} do
      session = text_scale_session(user, album, @album_options)

      Cache.put(:sessions, "5678", %{
        id: session.id,
        vote_options: session.vote_options,
        current_track_id: nil,
        vote_scope: :album
      })

      PremiereEcoute.PubSub.subscribe("session:#{session.id}")

      PremiereEcouteCore.publish(MessagePipeline, %MessageSent{
        broadcaster_id: "5678",
        user_id: "viewer1",
        message: "smash",
        is_streamer: false
      })

      assert_receive {:session_summary, %{viewer_score: "smash"}}, 1_000
    end

    test "broadcasts the track summary for a text vote scale", %{user: user, album: album} do
      session = text_scale_session(user, album, %{"votes" => 0, "scores" => 0, "next_track" => 0})
      track = hd(album.tracks)
      Cache.put(:sessions, "5678", %{id: session.id, vote_options: session.vote_options, current_track_id: track.id})
      PremiereEcoute.PubSub.subscribe("session:#{session.id}")

      PremiereEcouteCore.publish(MessagePipeline, %MessageSent{
        broadcaster_id: "5678",
        user_id: "viewer1",
        message: "pass",
        is_streamer: false
      })

      assert_receive {:session_summary, %{viewer_score: "pass"}}, 1_000
    end
  end

  describe "VoteTrends.track_distribution/1 - album scope" do
    test "ignores album votes", %{session: session} do
      {:ok, _} = Vote.create(album_vote(session, "v1", "8"))

      assert VoteTrends.track_distribution(session.id) == %{}
    end
  end

  describe "PostSessionVote.submit_album/3" do
    setup %{session: session} do
      {:ok, session} = ListeningSession.update(session, %{status: :stopped})
      {:ok, %{session: session}}
    end

    test "stores an album vote and regenerates the report", %{user: user, session: session} do
      assert {:ok, %Report{} = report} = PostSessionVote.submit_album(session, user, "9")

      assert [%Vote{scope: :album, track_id: nil, value: "9", viewer_id: "1234"}] =
               Vote.all(where: [session_id: session.id])

      assert report.session_summary.viewer_score == 9.0
    end

    test "ignores a second album vote", %{user: user, session: session} do
      {:ok, _} = PostSessionVote.submit_album(session, user, "9")
      {:ok, _} = PostSessionVote.submit_album(session, user, "1")

      assert [%Vote{value: "9"}] = Vote.all(where: [session_id: session.id])
    end

    test "rejects a value outside of the vote options", %{user: user, session: session} do
      assert {:error, :invalid_votes} = PostSessionVote.submit_album(session, user, "42")
    end

    test "rejects a session that is not in album scope", %{user: user, session: session} do
      {:ok, session} = ListeningSession.update(session, %{options: %{"vote_scope" => "track"}})

      assert {:error, :invalid} = PostSessionVote.submit_album(session, user, "9")
    end

    test "rejects an active session", %{user: user, session: session} do
      {:ok, session} = ListeningSession.update(session, %{status: :active})

      assert {:error, :invalid} = PostSessionVote.submit_album(session, user, "9")
    end
  end
end
