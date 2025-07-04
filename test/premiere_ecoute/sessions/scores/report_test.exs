defmodule PremiereEcoute.Sessions.Scores.ReportTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.{Poll, Report, Vote}

  describe "generate/1" do
    test "generates comprehensive report with all vote sources" do
      user = user_fixture()
      {:ok, album} = Album.create(album_fixture())
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})

      [track1, track2] = album.tracks

      viewer_votes = [
        %Vote{
          viewer_id: "viewer1",
          session_id: session.id,
          track_id: track1.id,
          value: 8,
          is_streamer: false
        },
        %Vote{
          viewer_id: "viewer2",
          session_id: session.id,
          track_id: track1.id,
          value: 6,
          is_streamer: false
        },
        %Vote{
          viewer_id: "viewer3",
          session_id: session.id,
          track_id: track1.id,
          value: 7,
          is_streamer: false
        },
        %Vote{
          viewer_id: "viewer1",
          session_id: session.id,
          track_id: track2.id,
          value: 9,
          is_streamer: false
        },
        %Vote{
          viewer_id: "viewer2",
          session_id: session.id,
          track_id: track2.id,
          value: 5,
          is_streamer: false
        },
        %Vote{
          viewer_id: "viewer3",
          session_id: session.id,
          track_id: track2.id,
          value: 8,
          is_streamer: false
        }
      ]

      streamer_votes = [
        %Vote{
          viewer_id: "streamer",
          session_id: session.id,
          track_id: track1.id,
          value: 9,
          is_streamer: true
        },
        %Vote{
          viewer_id: "streamer",
          session_id: session.id,
          track_id: track2.id,
          value: 7,
          is_streamer: true
        }
      ]

      for vote <- viewer_votes ++ streamer_votes do
        {:ok, _} = Vote.create(vote)
      end

      polls = [
        %Poll{
          poll_id: "twitch_poll_track1",
          title: "Rate Track 1",
          session_id: session.id,
          track_id: track1.id,
          votes: %{"5" => 2, "8" => 3, "10" => 1},
          total_votes: 6
        },
        %Poll{
          poll_id: "twitch_poll_track2",
          title: "Rate Track 2",
          session_id: session.id,
          track_id: track2.id,
          votes: %{"6" => 1, "9" => 2, "10" => 2},
          total_votes: 5
        }
      ]

      for poll <- polls do
        {:ok, _} = Poll.create(poll)
      end

      {:ok, report} = Report.generate(session)

      assert report.session_id == session.id
      assert report.unique_votes == 19
      assert report.unique_voters == 14

      session_summary = report.session_summary
      assert session_summary.tracks_rated == 2
      assert_in_delta session_summary.viewer_score, 7.615, 0.1
      assert session_summary.streamer_score == 8.0

      track_summaries = report.track_summaries
      assert length(track_summaries) == 2

      track1_summary = Enum.find(track_summaries, &(&1.track_id == track1.id))
      track2_summary = Enum.find(track_summaries, &(&1.track_id == track2.id))

      assert track1_summary.individual_count == 4
      assert track1_summary.poll_count == 6
      assert track1_summary.unique_voters == 9
      assert_in_delta track1_summary.viewer_score, 7.165, 0.1
      assert track1_summary.streamer_score == 9.0

      assert track2_summary.individual_count == 4
      assert track2_summary.poll_count == 5
      assert track2_summary.unique_voters == 8
      assert_in_delta track2_summary.viewer_score, 8.065, 0.1
      assert track2_summary.streamer_score == 7.0
    end
  end
end
