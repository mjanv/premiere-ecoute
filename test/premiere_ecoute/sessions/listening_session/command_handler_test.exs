defmodule PremiereEcoute.Sessions.ListeningSession.CommandCommandHandlerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.CommandHandler
  alias PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionNotPrepared
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionPrepared
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped
  alias PremiereEcoute.Sessions.Scores.Report

  describe "handle/1 - PrepareListeningSession" do
    test "successfully creates session and returns SessionPrepared event" do
      user = user_fixture()
      album = album_fixture()

      PremiereEcoute.Apis.SpotifyApiMock
      |> expect(:get_album, fn _ -> {:ok, album} end)

      command = %PrepareListeningSession{
        user_id: user.id,
        album_id: album.id
      }

      {:ok, session, [%SessionPrepared{}]} = CommandHandler.handle(command)

      assert session.user_id == user.id
      assert session.status == :preparing

      assert session.album.spotify_id == "album123"
      assert session.album.name == "Sample Album"
      assert session.album.artist == "Sample Artist"
    end

    test "returns SessionNotPrepared when SpotifyApi fails" do
      user_id = 1
      album_id = "spotify:album:invalid"

      PremiereEcoute.Apis.SpotifyApiMock
      |> expect(:get_album, fn ^album_id -> {:error, :not_found} end)

      command = %PrepareListeningSession{
        user_id: user_id,
        album_id: album_id
      }

      {:error, [%SessionNotPrepared{} = event]} = CommandHandler.handle(command)

      assert event.user_id == user_id
    end

    test "returns SessionNotPrepared when album creation fails" do
      user_id = 1
      album_id = "spotify:album:123"

      album = %Album{
        spotify_id: album_id,
        # Invalid name to trigger creation failure
        name: nil,
        artist: "Test Artist",
        cover_url: nil,
        release_date: nil,
        total_tracks: 0,
        tracks: []
      }

      PremiereEcoute.Apis.SpotifyApiMock
      |> expect(:get_album, fn ^album_id -> {:ok, album} end)

      command = %PrepareListeningSession{
        user_id: user_id,
        album_id: album_id
      }

      {:error, [%SessionNotPrepared{} = event]} = CommandHandler.handle(command)

      assert event.user_id == user_id
    end

    test "handles duplicate session creation gracefully" do
      user = user_fixture()
      album = album_fixture()

      PremiereEcoute.Apis.SpotifyApiMock
      |> expect(:get_album, 2, fn _ -> {:ok, album} end)

      command = %PrepareListeningSession{
        user_id: user.id,
        album_id: album.id
      }

      {:ok, _, [event1]} = CommandHandler.handle(command)
      {:ok, _, [event2]} = CommandHandler.handle(command)

      assert event1.session_id != event2.session_id
    end
  end

  describe "handle/1 - StartListeningSession" do
    test "successfully start a prepare session and returns SessionStarted event" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      album = album_fixture()

      PremiereEcoute.Apis.SpotifyApiMock
      |> expect(:get_album, fn _ -> {:ok, album} end)

      PremiereEcoute.Apis.TwitchApiMock
      |> expect(:subscribe, fn %Scope{user: ^user}, "channel.chat.message" ->
        {:ok, %{}}
      end)

      PremiereEcoute.Apis.TwitchApiMock
      |> expect(:subscribe, fn %Scope{user: ^user}, "channel.poll.progress" ->
        {:ok, %{}}
      end)

      command = %PrepareListeningSession{
        user_id: user.id,
        album_id: album.id
      }

      {:ok, _, [%SessionPrepared{} = event]} = CommandHandler.handle(command)

      command = %StartListeningSession{session_id: event.session_id, scope: scope}

      {:ok, _, [%SessionStarted{} = event]} = CommandHandler.handle(command)

      session = ListeningSession.get(event.session_id)

      assert session.status == :active
      assert session.current_track_id == hd(session.album.tracks).id
    end
  end

  describe "handle/1 - StopListeningSession" do
    test "successfully creates session and generate a report" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      album = album_fixture()

      PremiereEcoute.Apis.SpotifyApiMock
      |> expect(:get_album, fn _ -> {:ok, album} end)

      PremiereEcoute.Apis.TwitchApiMock
      |> expect(:subscribe, fn %Scope{user: ^user}, "channel.chat.message" ->
        {:ok, %{}}
      end)

      PremiereEcoute.Apis.TwitchApiMock
      |> expect(:subscribe, fn %Scope{user: ^user}, "channel.poll.progress" ->
        {:ok, %{}}
      end)

      command = %PrepareListeningSession{
        user_id: user.id,
        album_id: album.id
      }

      {:ok, _, [%SessionPrepared{} = event]} = CommandHandler.handle(command)

      command = %StartListeningSession{session_id: event.session_id, scope: scope}

      {:ok, _, [%SessionStarted{} = event]} = CommandHandler.handle(command)

      command = %StopListeningSession{session_id: event.session_id}

      {:ok, session, [%SessionStopped{}]} = CommandHandler.handle(command)

      report = Report.get_by(session_id: session.id)

      assert session.status == :stopped

      assert %PremiereEcoute.Sessions.Scores.Report{
               unique_votes: 0,
               polls: [],
               session_id: session_id,
               session_summary: %{
                 "streamer_score" => +0.0,
                 "tracks_rated" => 0,
                 "viewer_score" => +0.0
               },
               track_summaries: [],
               unique_voters: 0,
               votes: []
             } = report

      assert session_id == session.id
    end
  end
end
