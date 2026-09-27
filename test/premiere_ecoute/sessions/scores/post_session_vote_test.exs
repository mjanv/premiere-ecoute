defmodule PremiereEcoute.Sessions.Scores.PostSessionVoteTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.PostSessionVote
  alias PremiereEcoute.Sessions.Scores.Vote

  setup do
    user = user_fixture(%{twitch: %{}})
    {:ok, album} = Album.create(album_fixture())
    {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id, status: :stopped})

    {:ok, %{user: user, album: album, session: session}}
  end

  describe "has_voted?/2" do
    test "returns false for a stopped session when the viewer has not voted", %{user: user, session: session} do
      refute PostSessionVote.has_voted?(session, user)
    end

    test "returns true for a stopped session when the viewer has voted", %{user: user, album: album, session: session} do
      track = hd(album.tracks)

      {:ok, _} =
        Vote.create(%Vote{
          viewer_id: user.twitch.user_id,
          session_id: session.id,
          track_id: track.id,
          value: "8",
          is_streamer: false
        })

      assert PostSessionVote.has_voted?(session, user)
    end

    test "returns false without raising for a non-stopped session, even if the viewer has voted", %{
      user: user,
      album: album,
      session: session
    } do
      track = hd(album.tracks)
      {:ok, active_session} = ListeningSession.update(session, %{status: :active})

      {:ok, _} =
        Vote.create(%Vote{
          viewer_id: user.twitch.user_id,
          session_id: active_session.id,
          track_id: track.id,
          value: "8",
          is_streamer: false
        })

      refute PostSessionVote.has_voted?(active_session, user)
    end

    test "returns false for a user without a linked twitch account", %{session: session} do
      user_without_twitch = user_fixture()

      refute PostSessionVote.has_voted?(session, user_without_twitch)
    end
  end

  describe "submit/3" do
    test "inserts votes and regenerates the report for a stopped session", %{user: user, album: album, session: session} do
      track = hd(album.tracks)

      assert {:ok, %Report{} = report} = PostSessionVote.submit(session, user, %{track.id => "9"})
      assert report.session_id == session.id

      vote = Vote.get_by(viewer_id: user.twitch.user_id, session_id: session.id, track_id: track.id)
      assert vote.value == "9"
    end

    test "ignores duplicate votes for the same viewer, session and track", %{user: user, album: album, session: session} do
      track = hd(album.tracks)

      {:ok, _} =
        Vote.create(%Vote{
          viewer_id: user.twitch.user_id,
          session_id: session.id,
          track_id: track.id,
          value: "3",
          is_streamer: false
        })

      {:ok, _report} = PostSessionVote.submit(session, user, %{track.id => "9"})

      vote = Vote.get_by(viewer_id: user.twitch.user_id, session_id: session.id, track_id: track.id)
      assert vote.value == "3"
    end

    test "returns an error for a session that is not stopped", %{user: user, album: album, session: session} do
      track = hd(album.tracks)
      {:ok, active_session} = ListeningSession.update(session, %{status: :active})

      assert {:error, :invalid} = PostSessionVote.submit(active_session, user, %{track.id => "9"})
    end

    test "rejects the whole batch when a value is not one of the session vote options", %{
      user: user,
      album: album,
      session: session
    } do
      [track1, track2 | _] = album.tracks

      assert {:error, :invalid_votes} = PostSessionVote.submit(session, user, %{track1.id => "8", track2.id => "abc"})

      refute PostSessionVote.has_voted?(session, user)
    end

    test "rejects the whole batch when a track does not belong to the session", %{
      user: user,
      album: album,
      session: session
    } do
      {:ok, other_album} =
        Album.create(
          album_fixture(%{
            provider_ids: %{spotify: "album456"},
            tracks: [%Album.Track{provider_ids: %{spotify: "track999"}, name: "Other", track_number: 1, duration_ms: 1}]
          })
        )

      track = hd(album.tracks)
      foreign_track = hd(other_album.tracks)

      assert {:error, :invalid_votes} =
               PostSessionVote.submit(session, user, %{track.id => "8", foreign_track.id => "8"})

      refute PostSessionVote.has_voted?(session, user)
    end

    test "accepts votes on the tracks of a playlist session", %{user: user} do
      {:ok, playlist} = Playlist.create(playlist_fixture())

      {:ok, session} =
        ListeningSession.create(%{user_id: user.id, playlist_id: playlist.id, source: :playlist, status: :stopped})

      track = hd(playlist.tracks)

      assert {:ok, %Report{}} = PostSessionVote.submit(session, user, %{track.id => "7"})
      assert PostSessionVote.has_voted?(session, user)
    end
  end
end
