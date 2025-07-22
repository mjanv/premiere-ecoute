defmodule PremiereEcoute.Sessions.RetrospectiveTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.Discography.Track
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective
  alias PremiereEcoute.Sessions.Scores.Report
  alias PremiereEcoute.Sessions.Scores.Vote

  setup do
    user = user_fixture()
    {:ok, album1} = Album.create(spotify_album_fixture("7aJuG4TFXa2hmE4z1yxc3n"))
    {:ok, session1} = ListeningSession.create(%{user_id: user.id, album_id: album1.id})
    {:ok, session1} = ListeningSession.start(session1)
    {:ok, session1} = ListeningSession.stop(session1)
    {:ok, report1} = Report.generate(session1)

    {:ok, album2} = Album.create(spotify_album_fixture("5tzRuO6GP7WRvP3rEOPAO9"))
    {:ok, session2} = ListeningSession.create(%{user_id: user.id, album_id: album2.id})
    {:ok, session2} = ListeningSession.start(session2)

    {:ok, _} =
      Vote.create(%Vote{
        viewer_id: "viewer1",
        session_id: session2.id,
        track_id: Enum.at(album2.tracks, 0).id,
        value: "9",
        is_streamer: false
      })

    {:ok, _} =
      Vote.create(%Vote{
        viewer_id: "viewer2",
        session_id: session2.id,
        track_id: Enum.at(album2.tracks, 0).id,
        value: "7",
        is_streamer: false
      })

    {:ok, _} =
      Vote.create(%Vote{
        viewer_id: "viewer1",
        session_id: session2.id,
        track_id: Enum.at(album2.tracks, 1).id,
        value: "7",
        is_streamer: false
      })

    {:ok, session2} = ListeningSession.stop(session2)
    {:ok, report2} = Report.generate(session2)

    {:ok, album3} = Album.create(spotify_album_fixture("0S0KGZnfBGSIssfF54WSJh"))
    {:ok, session3} = ListeningSession.create(%{user_id: user.id, album_id: album3.id})
    {:ok, session3} = ListeningSession.start(session3)
    {:ok, session3} = ListeningSession.stop(session3)
    {:ok, report3} = Report.generate(session3)

    {:ok, %{user: user, sessions: [session1, session2, session3]}}
  end

  describe "get_albums_by_period/3" do
    test "?", %{user: user} do
      retrospective = Retrospective.get_albums_by_period(user.id, :month)

      assert length(retrospective) == 3

      for entry <- retrospective do
        %{album: %Album{}, session: %ListeningSession{}, report: %Report{}} = entry
      end
    end
  end

  describe "get_album_session_details/1" do
    test "return no tracks if no votes have been casted", %{sessions: [session | _]} do
      {:ok, details} = Retrospective.get_album_session_details(session.id)

      assert %{session: %ListeningSession{}, tracks: []} = details
    end

    test "returns tracks with casted votes", %{sessions: [_, session | _]} do
      {:ok, details} = Retrospective.get_album_session_details(session.id)

      assert %{session: %ListeningSession{}, tracks: [track1, track2]} = details
      assert %{track_album: %Track{}, track_summary: summary1} = track1
      assert %{"streamer_score" => 0.0, "viewer_score" => 8.0} = summary1
      assert %{track_album: %Track{}, track_summary: summary2} = track2
      assert %{"streamer_score" => 0.0, "viewer_score" => 7.0} = summary2
    end
  end
end
