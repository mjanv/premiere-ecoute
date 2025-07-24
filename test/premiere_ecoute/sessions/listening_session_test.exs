defmodule PremiereEcoute.Sessions.ListeningSessionTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.Discography.Album.Track
  alias PremiereEcoute.Sessions.ListeningSession

  setup do
    user = user_fixture()
    {:ok, album} = Album.create(album_fixture())

    {:ok, %{user: user, album: album}}
  end

  describe "create/1" do
    test "can create a new listening session for an existing user and album", %{
      user: user,
      album: album
    } do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})

      assert %PremiereEcoute.Sessions.ListeningSession{
               status: :preparing,
               vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
               started_at: nil,
               ended_at: nil,
               current_track: nil,
               album: album
             } = session

      assert %Album{
               spotify_id: "album123",
               name: "Sample Album",
               artist: "Sample Artist",
               release_date: ~D[2023-01-01],
               cover_url: "http://example.com/cover.jpg",
               total_tracks: 2,
               tracks: [
                 %Track{
                   spotify_id: "track001",
                   name: "Track One",
                   track_number: 1,
                   duration_ms: 210_000
                 },
                 %Track{
                   spotify_id: "track002",
                   name: "Track Two",
                   track_number: 2,
                   duration_ms: 180_000
                 }
               ]
             } = album
    end

    test "can create a new listening session with different voting options", %{
      user: user,
      album: album
    } do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id, vote_options: ["smash", "pass"]})

      assert %PremiereEcoute.Sessions.ListeningSession{
               status: :preparing,
               vote_options: ["smash", "pass"],
               started_at: nil,
               ended_at: nil,
               current_track: nil,
               album: _
             } = session
    end
  end

  describe "get/1" do
    test "can get an existing listening session", %{user: user, album: album} do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})

      session = ListeningSession.get(session.id)

      assert %PremiereEcoute.Sessions.ListeningSession{
               status: :preparing,
               started_at: nil,
               album: album,
               ended_at: nil
             } = session

      assert %Album{
               spotify_id: "album123",
               name: "Sample Album",
               artist: "Sample Artist",
               release_date: ~D[2023-01-01],
               cover_url: "http://example.com/cover.jpg",
               total_tracks: 2,
               tracks: [
                 %Track{
                   spotify_id: "track001",
                   name: "Track One",
                   track_number: 1,
                   duration_ms: 210_000
                 },
                 %Track{
                   spotify_id: "track002",
                   name: "Track Two",
                   track_number: 2,
                   duration_ms: 180_000
                 }
               ]
             } = album
    end
  end

  describe "all/0" do
    test "can get all existing listening sessions", %{user: user, album: album} do
      {:ok, _} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, _} = ListeningSession.create(%{user_id: user.id, album_id: album.id})

      sessions = ListeningSession.all(where: [user_id: user.id])

      for session <- sessions do
        assert %PremiereEcoute.Sessions.ListeningSession{
                 status: :preparing,
                 started_at: nil,
                 album: album,
                 ended_at: nil
               } = session

        assert %Album{
                 spotify_id: "album123",
                 name: "Sample Album",
                 artist: "Sample Artist",
                 release_date: ~D[2023-01-01],
                 cover_url: "http://example.com/cover.jpg",
                 total_tracks: 2,
                 tracks: [
                   %Track{
                     spotify_id: "track001",
                     name: "Track One",
                     track_number: 1,
                     duration_ms: 210_000
                   },
                   %Track{
                     spotify_id: "track002",
                     name: "Track Two",
                     track_number: 2,
                     duration_ms: 180_000
                   }
                 ]
               } = album
      end
    end
  end

  describe "start/1" do
    test "can mark an existing listening to be started", %{user: user, album: album} do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})

      {:ok, after_session} = ListeningSession.start(session)

      assert {session.status, after_session.status} == {:preparing, :active}
      assert is_nil(session.started_at)
      assert after_session.started_at.__struct__ == DateTime
    end
  end

  describe "next_track/1" do
    test "select the first track when no current track is selected", %{user: user, album: album} do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, session} = ListeningSession.start(session)

      {:ok, after_session} = ListeningSession.next_track(session)

      assert is_nil(session.current_track)

      assert %PremiereEcoute.Sessions.Discography.Album.Track{
               name: "Track One",
               spotify_id: "track001",
               track_number: 1
             } = after_session.current_track
    end

    test "select the second track when the first track is selected", %{user: user, album: album} do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, session} = ListeningSession.start(session)

      {:ok, session} = ListeningSession.next_track(session)
      {:ok, after_session} = ListeningSession.next_track(session)

      assert %PremiereEcoute.Sessions.Discography.Album.Track{
               name: "Track One",
               spotify_id: "track001",
               track_number: 1
             } = session.current_track

      assert %PremiereEcoute.Sessions.Discography.Album.Track{
               name: "Track Two",
               spotify_id: "track002",
               track_number: 2
             } = after_session.current_track
    end

    test "cannot select the next track when the last track is selected", %{
      user: user,
      album: album
    } do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, session} = ListeningSession.start(session)

      {:ok, session} = ListeningSession.next_track(session)
      {:ok, session} = ListeningSession.next_track(session)
      {:error, reason} = ListeningSession.next_track(session)

      assert reason == :no_tracks_left
    end
  end

  describe "previous_track/1" do
    test "cannot select the previous track when no current track is selected", %{
      user: user,
      album: album
    } do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, session} = ListeningSession.start(session)

      {:error, reason} = ListeningSession.previous_track(session)

      assert reason == :no_tracks_left
    end

    test "cannot select the previous track the first track is selected", %{
      user: user,
      album: album
    } do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, session} = ListeningSession.start(session)

      {:ok, session} = ListeningSession.next_track(session)
      {:error, reason} = ListeningSession.previous_track(session)

      assert reason == :no_tracks_left
    end

    test "cannot select the previous track when the last track is selected", %{
      user: user,
      album: album
    } do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, session} = ListeningSession.start(session)

      {:ok, session} = ListeningSession.next_track(session)
      {:ok, session} = ListeningSession.next_track(session)
      {:ok, after_session} = ListeningSession.previous_track(session)

      assert %PremiereEcoute.Sessions.Discography.Album.Track{
               name: "Track Two",
               spotify_id: "track002",
               track_number: 2
             } = session.current_track

      assert %PremiereEcoute.Sessions.Discography.Album.Track{
               name: "Track One",
               spotify_id: "track001",
               track_number: 1
             } = after_session.current_track
    end
  end

  describe "stop/1" do
    test "can mark a started listening session to be stopped", %{user: user, album: album} do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, session} = ListeningSession.start(session)

      {:ok, after_session} = ListeningSession.stop(session)

      assert {session.status, after_session.status} == {:active, :stopped}
      assert is_nil(session.ended_at)
      assert after_session.ended_at.__struct__ == DateTime
    end

    test "cannot mark a prepared listening session to be stopped", %{user: user, album: album} do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})

      {:error, reason} = ListeningSession.stop(session)

      assert reason == :invalid_status
    end
  end

  describe "delete/1" do
    test "can delete an existing listening session", %{user: user, album: album} do
      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})

      ListeningSession.delete(session)

      assert is_nil(ListeningSession.get(session.id))
    end
  end
end
