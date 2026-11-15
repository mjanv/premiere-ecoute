defmodule PremiereEcoute.Sessions.Retrospective.HistoryTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.History
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Vote

  setup do
    user = user_fixture()
    viewer = user_fixture(%{twitch: %{user_id: "viewer1"}})

    {:ok, album1} = Album.create(spotify_album_fixture("7aJuG4TFXa2hmE4z1yxc3n"))
    {:ok, session1} = ListeningSession.create(%{user_id: user.id, album_id: album1.id})
    {:ok, session1} = ListeningSession.start(session1)
    {:ok, session1} = ListeningSession.stop(session1)
    {:ok, _report1} = Report.generate(session1)

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
    {:ok, _report2} = Report.generate(session2)

    {:ok, album3} = Album.create(spotify_album_fixture("0S0KGZnfBGSIssfF54WSJh"))
    {:ok, session3} = ListeningSession.create(%{user_id: user.id, album_id: album3.id})
    {:ok, session3} = ListeningSession.start(session3)
    {:ok, session3} = ListeningSession.stop(session3)
    {:ok, _report3} = Report.generate(session3)

    {:ok, %{user: user, viewer: viewer, sessions: [session1, session2, session3]}}
  end

  describe "get_albums_by_period/2" do
    test "returns the list of albums grouped per month", %{user: user} do
      retrospective = History.get_albums_by_period(user, :month)

      assert length(retrospective) == 3

      for entry <- retrospective do
        %{album: %Album{}, session: %ListeningSession{}, report: %Report{}} = entry
      end
    end

    test "returns the list of albums grouped per year", %{user: user} do
      retrospective = History.get_albums_by_period(user, :year)

      assert length(retrospective) == 3

      for entry <- retrospective do
        %{album: %Album{}, session: %ListeningSession{}, report: %Report{}} = entry
      end
    end
  end

  describe "get_votes_by_period/2" do
    test "returns the list of votes grouped per month", %{viewer: viewer} do
      retrospective = History.get_votes_by_period(viewer, :month)

      assert length(retrospective) == 1

      for entry <- retrospective do
        %{album: %Album{}, score: _score} = entry
      end
    end

    test "returns the list of votes grouped per year", %{viewer: viewer} do
      retrospective = History.get_votes_by_period(viewer, :year)

      assert length(retrospective) == 1

      for entry <- retrospective do
        %{album: %Album{}, score: _score} = entry
      end
    end
  end

  describe "get_top_tracks_by_period/3" do
    test "returns only the viewer's votes, sorted by score descending", %{viewer: viewer} do
      results = History.get_top_tracks_by_period(viewer, :all)

      # viewer1 has 2 votes; viewer2's vote on track 0 must not appear
      assert length(results) == 2

      [first, second] = results

      assert %{
               track: %Track{
                 name: "Getting Older",
                 track_number: 1,
                 album: %Album{name: "Happier Than Ever"}
               },
               score: "9",
               voted_at: %DateTime{}
             } = first

      assert %{
               track: %Track{
                 name: "I Didn't Change My Number",
                 track_number: 2,
                 album: %Album{name: "Happier Than Ever"}
               },
               score: "7",
               voted_at: %DateTime{}
             } = second
    end
  end

  describe "get_clips_by_period/3" do
    setup %{user: user, viewer: viewer} do
      {:ok, single} = Single.create(single_fixture(%{provider_ids: %{spotify: "spotify_clip_1", youtube: "yt_clip_1"}}))
      {:ok, session} = ListeningSession.create(%{user_id: user.id, source: :clip, single_id: single.id})
      {:ok, session} = ListeningSession.start(session)

      {:ok, _} =
        Vote.create(%Vote{
          viewer_id: viewer.twitch.user_id,
          session_id: session.id,
          track_id: single.id,
          value: "8",
          is_streamer: false
        })

      {:ok, session} = ListeningSession.stop(session)
      {:ok, _report} = Report.generate(session)

      # A sibling single-backed :track session in the same period, so the
      # source filter itself is proven load-bearing: if `s.source == :clip`
      # were dropped or swapped, this session would leak into the results too.
      {:ok, track_single} = Single.create(single_fixture(%{provider_ids: %{spotify: "spotify_track_sibling"}}))
      {:ok, track_session} = ListeningSession.create(%{user_id: user.id, source: :track, single_id: track_single.id})
      {:ok, track_session} = ListeningSession.start(track_session)

      {:ok, _} =
        Vote.create(%Vote{
          viewer_id: viewer.twitch.user_id,
          session_id: track_session.id,
          track_id: track_single.id,
          value: "5",
          is_streamer: false
        })

      {:ok, track_session} = ListeningSession.stop(track_session)
      {:ok, _report} = Report.generate(track_session)

      {:ok, clip_session: session, clip_single: single}
    end

    test "returns only clip sessions, not sibling single-backed sessions of other sources", %{
      user: user,
      clip_session: clip_session
    } do
      retrospective = History.get_clips_by_period(user, :month)

      assert length(retrospective) == 1
      assert [%{single: %Single{}, session: %ListeningSession{id: id}, report: %Report{}}] = retrospective
      assert id == clip_session.id
    end

    test "returns only votes on clip sessions, not votes on sibling single-backed sessions", %{
      viewer: viewer,
      clip_single: clip_single
    } do
      retrospective = History.get_clip_votes_by_period(viewer, :month)

      assert [%{single: %Single{id: id}, score: score}] = retrospective
      assert id == clip_single.id
      assert Decimal.equal?(score, Decimal.new("8.0"))
    end
  end

  describe "get_singles_by_period/3 with sort: :score" do
    setup %{user: user, viewer: viewer} do
      {:ok, low_single} = Single.create(single_fixture(%{provider_ids: %{spotify: "spotify_low"}}))
      {:ok, low_session} = ListeningSession.create(%{user_id: user.id, source: :track, single_id: low_single.id})
      {:ok, low_session} = ListeningSession.start(low_session)

      {:ok, _} =
        Vote.create(%Vote{
          viewer_id: viewer.twitch.user_id,
          session_id: low_session.id,
          track_id: low_single.id,
          value: "3",
          is_streamer: false
        })

      {:ok, low_session} = ListeningSession.stop(low_session)
      {:ok, _report} = Report.generate(low_session)

      {:ok, high_single} = Single.create(single_fixture(%{provider_ids: %{spotify: "spotify_high"}}))
      {:ok, high_session} = ListeningSession.create(%{user_id: user.id, source: :track, single_id: high_single.id})
      {:ok, high_session} = ListeningSession.start(high_session)

      {:ok, _} =
        Vote.create(%Vote{
          viewer_id: viewer.twitch.user_id,
          session_id: high_session.id,
          track_id: high_single.id,
          value: "9",
          is_streamer: false
        })

      {:ok, high_session} = ListeningSession.stop(high_session)
      {:ok, _report} = Report.generate(high_session)

      {:ok, no_votes_single} = Single.create(single_fixture(%{provider_ids: %{spotify: "spotify_no_votes"}}))

      {:ok, no_votes_session} =
        ListeningSession.create(%{user_id: user.id, source: :track, single_id: no_votes_single.id})

      {:ok, no_votes_session} = ListeningSession.start(no_votes_session)
      {:ok, no_votes_session} = ListeningSession.stop(no_votes_session)
      {:ok, _report} = Report.generate(no_votes_session)

      {:ok, low_session: low_session, high_session: high_session, no_votes_session: no_votes_session}
    end

    test "orders sessions by viewer_score descending, unscored sessions last", %{
      user: user,
      low_session: low_session,
      high_session: high_session,
      no_votes_session: no_votes_session
    } do
      retrospective = History.get_singles_by_period(user, :month, %{sort: :score})

      ids = Enum.map(retrospective, & &1.session.id)

      assert ids == [high_session.id, low_session.id, no_votes_session.id]
    end
  end

  describe "get_album_session_details/1" do
    test "return no tracks if no votes have been casted", %{sessions: [session | _]} do
      {:ok, details} = History.get_album_session_details(session.id)

      assert %{session: %ListeningSession{}, tracks: []} = details
    end

    test "returns tracks with casted votes", %{sessions: [_, session | _]} do
      {:ok, details} = History.get_album_session_details(session.id)

      assert %{session: %ListeningSession{}, tracks: [track1, track2]} = details
      assert %{track_album: %Track{}, track_summary: summary1} = track1
      assert %{streamer_score: nil, viewer_score: 8.0} = summary1
      assert %{track_album: %Track{}, track_summary: summary2} = track2
      assert %{streamer_score: nil, viewer_score: 7.0} = summary2
    end
  end

  describe "get_viewer_votes_by_year/3" do
    import PremiereEcoute.Wrapped.WrappedFixtures, only: [listened: 3, listened: 4, listened_single: 3, listened_single: 4]

    setup do
      {:ok, streamer: user_fixture(%{role: :streamer}), voter: user_fixture(%{twitch: %{user_id: "voter"}})}
    end

    test "lists the album votes of a viewer with their session", %{streamer: streamer, voter: voter} do
      album = listened(streamer, 901, ["8", "6"], viewer: "voter", album: "9", voted_at: ~U[2026-05-05 20:00:00Z])

      votes = History.get_viewer_votes_by_year(voter, 2026, :album)

      assert length(votes) == 3
      assert Enum.all?(votes, &(&1.album_id == album.id and &1.single_id == nil and &1.streamer == streamer.username))

      assert Enum.all?(
               votes,
               &(&1.vote_options == ListeningSession.vote_options("0-10") and &1.voted_at == ~U[2026-05-05 20:00:00Z])
             )

      assert votes |> Enum.map(&{&1.scope, &1.value}) |> Enum.sort() == [album: "9", track: "6", track: "8"]

      assert votes |> Enum.map(& &1.track_id) |> Enum.reject(&is_nil/1) |> Enum.sort() ==
               album.tracks |> Enum.map(& &1.id) |> Enum.sort()

      assert votes |> Enum.map(& &1.session_id) |> Enum.uniq() |> length() == 1
    end

    test "lists the single votes of a viewer apart from the album ones", %{streamer: streamer, voter: voter} do
      listened(streamer, 901, ["8"], viewer: "voter")
      single = listened_single(streamer, 901, "7", viewer: "voter")
      year = Date.utc_today().year

      assert [%{single_id: single_id, album_id: nil, value: "7", scope: :track}] =
               History.get_viewer_votes_by_year(voter, year, :track)

      assert single_id == single.id
      assert [%{single_id: nil, value: "8"}] = History.get_viewer_votes_by_year(voter, year, :album)
    end

    test "keeps the votes cast in the UTC year", %{streamer: streamer, voter: voter} do
      listened(streamer, 901, ["1"], viewer: "voter", voted_at: ~U[2025-12-31 23:59:59Z])
      listened(streamer, 902, ["2"], viewer: "voter", voted_at: ~U[2026-01-01 00:00:00Z])
      listened(streamer, 903, ["3"], viewer: "voter", voted_at: ~U[2026-12-31 23:59:59Z])
      listened(streamer, 904, ["4"], viewer: "voter", voted_at: ~U[2027-01-01 00:00:00Z])

      assert [%{value: "1"}] = History.get_viewer_votes_by_year(voter, 2025, :album)
      assert History.get_viewer_votes_by_year(voter, 2026, :album) |> Enum.map(& &1.value) |> Enum.sort() == ["2", "3"]
      assert [%{value: "4"}] = History.get_viewer_votes_by_year(voter, 2027, :album)
    end

    test "counts votes cast as a streamer and in private sessions", %{streamer: streamer, voter: voter} do
      listened(streamer, 901, ["8"], viewer: "voter", is_streamer: true, visibility: :private)

      assert [%{value: "8"}] = History.get_viewer_votes_by_year(voter, Date.utc_today().year, :album)
    end

    test "ignores the votes of other viewers", %{streamer: streamer, voter: voter} do
      listened(streamer, 901, ["8"], viewer: "someone", others: [{"voter", "3"}])

      assert [%{value: "3"}] = History.get_viewer_votes_by_year(voter, Date.utc_today().year, :album)
    end

    test "lists nothing for a user without Twitch account", %{streamer: streamer, voter: voter} do
      listened(streamer, 901, ["8"], viewer: "voter")
      year = Date.utc_today().year

      assert History.get_viewer_votes_by_year(streamer, year, :album) == []
      assert History.get_viewer_votes_by_year(%{voter | twitch: nil}, year, :album) == []
      assert History.get_viewer_votes_by_year(%{voter | twitch: %{voter.twitch | user_id: nil}}, year, :album) == []
    end
  end

  describe "list_voter_ids/1" do
    import PremiereEcoute.Wrapped.WrappedFixtures, only: [listened: 4, listened_single: 4]

    setup do
      {:ok, streamer: user_fixture(%{role: :streamer}), voter: user_fixture(%{twitch: %{user_id: "voter"}})}
    end

    test "lists the users whose Twitch account voted on an album or a single during the year", %{
      streamer: streamer,
      voter: voter,
      viewer: viewer
    } do
      other = user_fixture(%{twitch: %{user_id: "other"}})
      _silent = user_fixture(%{twitch: %{user_id: "silent"}})
      listened(streamer, 901, ["8", "6"], viewer: "voter", others: [{"stranger", "4"}])
      listened_single(streamer, 901, "8", viewer: "other")

      # `viewer` voted in the sessions of the setup
      assert Enum.sort(History.list_voter_ids(Date.utc_today().year)) == Enum.sort([viewer.id, voter.id, other.id])
    end

    test "ignores the votes of other years", %{streamer: streamer, voter: voter} do
      listened(streamer, 901, ["8"], viewer: "voter", voted_at: ~U[2025-12-31 23:59:59Z])

      assert History.list_voter_ids(2025) == [voter.id]
      assert History.list_voter_ids(2024) == []
      refute voter.id in History.list_voter_ids(2026)
    end

    test "counts votes cast as a streamer", %{streamer: streamer, voter: voter} do
      listened(streamer, 901, ["8"], viewer: "voter", is_streamer: true)

      assert voter.id in History.list_voter_ids(Date.utc_today().year)
    end

    test "ignores votes in sessions that are neither album nor single sessions", %{voter: voter, sessions: [session | _]} do
      {:ok, _} = session |> Ecto.Changeset.change(source: :free) |> Repo.update()
      {:ok, _} = Vote.create(%Vote{viewer_id: "voter", session_id: session.id, track_id: 1, value: "8"})

      refute voter.id in History.list_voter_ids(Date.utc_today().year)
    end
  end
end
