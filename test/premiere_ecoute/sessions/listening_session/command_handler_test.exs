defmodule PremiereEcoute.Sessions.ListeningSession.CommandHandlerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Core.CommandBus
  alias PremiereEcoute.Sessions.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionNotPrepared
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionPrepared
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped
  alias PremiereEcoute.Sessions.Scores.Report

  alias PremiereEcoute.Apis.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.TwitchApi.Mock, as: TwitchApi

  describe "handle/1 - PrepareListeningSession" do
    test "successfully creates session and returns SessionPrepared event" do
      user = user_fixture()
      album = album_fixture()

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)

      command = %PrepareListeningSession{
        user_id: user.id,
        album_id: album.id
      }

      {:ok, session, [%SessionPrepared{}]} = CommandBus.apply(command)

      assert session.user_id == user.id
      assert session.status == :preparing

      assert session.album.spotify_id == "album123"
      assert session.album.name == "Sample Album"
      assert session.album.artist == "Sample Artist"
    end

    test "returns SessionNotPrepared when SpotifyApi fails" do
      user_id = 1
      album_id = "spotify:album:invalid"

      expect(SpotifyApi, :get_album, fn ^album_id -> {:error, :not_found} end)

      command = %PrepareListeningSession{
        user_id: user_id,
        album_id: album_id
      }

      {:error, [%SessionNotPrepared{} = event]} = CommandBus.apply(command)

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

      expect(SpotifyApi, :get_album, fn ^album_id -> {:ok, album} end)

      command = %PrepareListeningSession{
        user_id: user_id,
        album_id: album_id
      }

      {:error, [%SessionNotPrepared{} = event]} = CommandBus.apply(command)

      assert event.user_id == user_id
    end

    test "handles duplicate session creation gracefully" do
      user = user_fixture()
      album = album_fixture()

      expect(SpotifyApi, :get_album, 2, fn _ -> {:ok, album} end)

      command = %PrepareListeningSession{
        user_id: user.id,
        album_id: album.id
      }

      {:ok, _, [event1]} = CommandBus.apply(command)
      {:ok, _, [event2]} = CommandBus.apply(command)

      assert event1.session_id != event2.session_id
    end
  end

  describe "handle/1 - StartListeningSession" do
    test "successfully start a prepare session and returns SessionStarted event" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      album = album_fixture()

      expect(TwitchApi, :cancel_all_subscriptions, fn %Scope{user: ^user} -> {:ok, []} end)

      expect(TwitchApi, :subscribe, fn %Scope{user: ^user}, "channel.chat.message" ->
        {:ok, %{}}
      end)

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)

      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ ->
        {:ok, "spotify:track:track001"}
      end)

      expect(TwitchApi, :send_chat_announcement, fn %Scope{user: ^user}, "Bienvenue !", _ ->
        {:ok, %{}}
      end)

      command = %PrepareListeningSession{
        user_id: user.id,
        album_id: album.id
      }

      {:ok, _, [%SessionPrepared{} = event]} = CommandBus.apply(command)

      command = %StartListeningSession{session_id: event.session_id, scope: scope}

      {:ok, _, [%SessionStarted{} = event]} = CommandBus.apply(command)

      session = ListeningSession.get(event.session_id)

      assert session.status == :active
      assert session.current_track_id == hd(session.album.tracks).id

      report = Report.get_by(session_id: session.id)

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

  describe "handle/1 - StopListeningSession" do
    test "successfully creates session and generate a report" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      album = album_fixture()

      expect(TwitchApi, :cancel_all_subscriptions, fn %Scope{user: ^user} -> {:ok, []} end)

      expect(TwitchApi, :subscribe, fn %Scope{user: ^user}, "channel.chat.message" ->
        {:ok, %{}}
      end)

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)

      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ ->
        {:ok, "spotify:track:track001"}
      end)

      expect(TwitchApi, :send_chat_announcement, fn %Scope{user: ^user}, _, _ -> {:ok, %{}} end)
      expect(TwitchApi, :cancel_all_subscriptions, fn %Scope{user: ^user} -> {:ok, []} end)
      expect(TwitchApi, :send_chat_announcement, fn %Scope{user: ^user}, _, _ -> {:ok, %{}} end)

      command = %PrepareListeningSession{
        user_id: user.id,
        album_id: album.id
      }

      {:ok, _, [%SessionPrepared{} = event]} = CommandBus.apply(command)

      command = %StartListeningSession{session_id: event.session_id, scope: scope}

      {:ok, _, [%SessionStarted{} = event]} = CommandBus.apply(command)

      command = %StopListeningSession{session_id: event.session_id, scope: scope}

      {:ok, session, [%SessionStopped{}]} = CommandBus.apply(command)

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
