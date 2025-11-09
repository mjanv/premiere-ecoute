defmodule PremiereEcoute.Sessions.ListeningSession.CommandHandlerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipNextTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.SkipPreviousTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StartListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.StopListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Events.NextTrackStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.PreviousTrackStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionNotPrepared
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionPrepared
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStopped
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcouteCore.CommandBus

  alias PremiereEcoute.Apis.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.TwitchApi.Mock, as: TwitchApi

  describe "handle/1 - PrepareListeningSession" do
    test "successfully creates album session and returns SessionPrepared event" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      album = album_fixture()

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)

      command = %PrepareListeningSession{
        source: :album,
        user_id: user.id,
        album_id: album.album_id
      }

      {:ok, session, [%SessionPrepared{}]} = CommandBus.apply(command)

      assert session.user_id == user.id
      assert session.status == :preparing

      assert session.album.album_id == "album123"
      assert session.album.name == "Sample Album"
      assert session.album.artist == "Sample Artist"
    end

    test "returns SessionNotPrepared when SpotifyApi fails" do
      user_id = 1
      album_id = "spotify:album:invalid"

      expect(SpotifyApi, :get_album, fn ^album_id -> {:error, :not_found} end)

      command = %PrepareListeningSession{
        source: :album,
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
        provider: :spotify,
        album_id: album_id,
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
        source: :album,
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
        source: :album,
        user_id: user.id,
        album_id: album.album_id
      }

      {:ok, _, [event1]} = CommandBus.apply(command)
      {:ok, _, [event2]} = CommandBus.apply(command)

      assert event1.session_id != event2.session_id
    end

    test "successfully creates playlist session and returns SessionPrepared event" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      playlist = playlist_fixture()

      expect(SpotifyApi, :get_playlist, fn _ -> {:ok, playlist} end)

      command = %PrepareListeningSession{
        source: :playlist,
        user_id: user.id,
        playlist_id: playlist.playlist_id
      }

      {:ok, session, [%SessionPrepared{}]} = CommandBus.apply(command)

      assert session.user_id == user.id
      assert session.status == :preparing

      assert session.playlist.playlist_id == playlist.playlist_id
      assert session.playlist.title == playlist.title
    end
  end

  describe "handle/1 - StartListeningSession" do
    test "successfully start a prepared album session and returns SessionStarted event" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      album = album_fixture()

      expect(TwitchApi, :cancel_all_subscriptions, fn %Scope{user: ^user} -> {:ok, []} end)
      expect(TwitchApi, :subscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      # expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track001"} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user},
                                               "Welcome to the premiere of Sample Album by Sample Artist",
                                               0 ->
        :ok
      end)

      # expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "(1/2) Track One", 0 -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to https://premiere-ecoute.fr/ using your Twitch account",
                                               0 ->
        :ok
      end)

      # expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !", 0 -> :ok end)

      command = %PrepareListeningSession{
        source: :album,
        user_id: user.id,
        album_id: album.album_id
      }

      {:ok, _, [%SessionPrepared{} = event]} = CommandBus.apply(command)

      command = %StartListeningSession{source: :album, session_id: event.session_id, scope: scope}

      {:ok, _, [%SessionStarted{} = event]} = CommandBus.apply(command)

      session = ListeningSession.get(event.session_id)

      assert session.status == :active
      assert session.current_track_id == nil

      report = Report.get_by(session_id: session.id)

      assert %PremiereEcoute.Sessions.Retrospective.Report{
               polls: [],
               session_id: session_id,
               session_summary: %{
                 "unique_votes" => 0,
                 "unique_voters" => 0,
                 "streamer_score" => nil,
                 "tracks_rated" => 0,
                 "viewer_score" => nil
               },
               track_summaries: [],
               votes: []
             } = report

      assert session_id == session.id
    end

    test "fails to start a session when user already has an active session" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      album = album_fixture()

      # First session setup - full expectations
      expect(TwitchApi, :cancel_all_subscriptions, fn %Scope{user: ^user} -> {:ok, []} end)
      expect(TwitchApi, :subscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(SpotifyApi, :get_album, 2, fn _ -> {:ok, album} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user},
                                               "Welcome to the premiere of Sample Album by Sample Artist",
                                               0 ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to https://premiere-ecoute.fr/ using your Twitch account",
                                               0 ->
        :ok
      end)

      # Second session setup - partial expectations (fails before most API calls)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(TwitchApi, :cancel_all_subscriptions, fn %Scope{user: ^user} -> {:ok, []} end)
      expect(TwitchApi, :subscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      # Prepare and start first session
      {:ok, _, [%SessionPrepared{} = event1]} =
        CommandBus.apply(%PrepareListeningSession{
          source: :album,
          user_id: user.id,
          album_id: album.album_id
        })

      {:ok, _, [%SessionStarted{}]} =
        CommandBus.apply(%StartListeningSession{source: :album, session_id: event1.session_id, scope: scope})

      # Prepare second session
      {:ok, _, [%SessionPrepared{} = event2]} =
        CommandBus.apply(%PrepareListeningSession{
          source: :album,
          user_id: user.id,
          album_id: album.album_id
        })

      # Try to start second session - should fail
      {:error, reason} = CommandBus.apply(%StartListeningSession{source: :album, session_id: event2.session_id, scope: scope})

      assert reason == "You already have an active listening session"
    end

    test "successfully start a prepared playlist session and returns SessionStarted event" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      playlist = playlist_fixture()

      expect(TwitchApi, :cancel_all_subscriptions, fn %Scope{user: ^user} -> {:ok, []} end)
      expect(TwitchApi, :subscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(SpotifyApi, :get_playlist, fn _ -> {:ok, playlist} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)

      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:playlist:2gW4sqiC2OXZLe9m0yDQX7"} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !", 0 -> :ok end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to https://premiere-ecoute.fr/ using your Twitch account",
                                               0 ->
        :ok
      end)

      command = %PrepareListeningSession{
        source: :playlist,
        user_id: user.id,
        playlist_id: playlist.playlist_id
      }

      {:ok, _, [%SessionPrepared{} = event]} = CommandBus.apply(command)

      command = %StartListeningSession{source: :playlist, session_id: event.session_id, scope: scope}

      {:ok, _, [%SessionStarted{} = event]} = CommandBus.apply(command)

      session = ListeningSession.get(event.session_id)

      assert session.status == :active

      report = Report.get_by(session_id: session.id)

      assert %PremiereEcoute.Sessions.Retrospective.Report{
               polls: [],
               session_id: session_id,
               session_summary: %{
                 "unique_votes" => 0,
                 "unique_voters" => 0,
                 "streamer_score" => nil,
                 "tracks_rated" => 0,
                 "viewer_score" => nil
               },
               track_summaries: [],
               votes: []
             } = report

      assert session_id == session.id
    end
  end

  describe "handle/1 - SkipNextTrackListeningSession" do
    test "successfully skip to the next track until none are left and returns NextTrackStarted event" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      album = album_fixture()

      expect(TwitchApi, :cancel_all_subscriptions, fn %Scope{user: ^user} -> {:ok, []} end)
      expect(TwitchApi, :subscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track001"} end)
      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track002"} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user},
                                               "Welcome to the premiere of Sample Album by Sample Artist",
                                               0 ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to https://premiere-ecoute.fr/ using your Twitch account",
                                               0 ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "(1/2) Track One", 0 -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !", 0 -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "(2/2) Track Two", 0 -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !", 0 -> :ok end)

      command = %PrepareListeningSession{
        source: :album,
        user_id: user.id,
        album_id: album.album_id
      }

      {:ok, _, [%SessionPrepared{} = event]} = CommandBus.apply(command)

      command = %StartListeningSession{source: :album, session_id: event.session_id, scope: scope}

      {:ok, _, [%SessionStarted{} = event]} = CommandBus.apply(command)

      session = ListeningSession.get(event.session_id)
      assert session.current_track_id == nil

      command = %SkipNextTrackListeningSession{source: :album, session_id: event.session_id, scope: scope}

      {:ok, _, [%NextTrackStarted{} = event]} = CommandBus.apply(command)

      session = ListeningSession.get(event.session_id)
      assert session.current_track_id == Enum.at(session.album.tracks, 0).id

      {:ok, _, [%NextTrackStarted{} = event]} = CommandBus.apply(command)

      session = ListeningSession.get(event.session_id)
      assert session.current_track_id == Enum.at(session.album.tracks, 1).id

      {:error, _} = CommandBus.apply(command)

      session = ListeningSession.get(event.session_id)
      assert session.current_track_id == Enum.at(session.album.tracks, 1).id
    end
  end

  describe "handle/1 - SkipPreviousTrackListeningSession" do
    test "successfully skip to the previous track until none are left and returns PreviousTrackStarted event" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      album = album_fixture()

      expect(TwitchApi, :cancel_all_subscriptions, fn %Scope{user: ^user} -> {:ok, []} end)
      expect(TwitchApi, :subscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track001"} end)
      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track002"} end)
      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track001"} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user},
                                               "Welcome to the premiere of Sample Album by Sample Artist",
                                               0 ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to https://premiere-ecoute.fr/ using your Twitch account",
                                               0 ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "(1/2) Track One", 0 -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !", 0 -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "(2/2) Track Two", 0 -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !", 0 -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "(1/2) Track One", 0 -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !", 0 -> :ok end)

      command = %PrepareListeningSession{
        source: :album,
        user_id: user.id,
        album_id: album.album_id
      }

      {:ok, _, [%SessionPrepared{} = event]} = CommandBus.apply(command)

      command = %StartListeningSession{source: :album, session_id: event.session_id, scope: scope}

      {:ok, _, [%SessionStarted{} = event]} = CommandBus.apply(command)

      session = ListeningSession.get(event.session_id)
      assert session.current_track_id == nil

      command = %SkipNextTrackListeningSession{source: :album, session_id: event.session_id, scope: scope}

      {:ok, _, [%NextTrackStarted{} = event]} = CommandBus.apply(command)

      session = ListeningSession.get(event.session_id)
      assert session.current_track_id == Enum.at(session.album.tracks, 0).id

      command = %SkipNextTrackListeningSession{source: :album, session_id: event.session_id, scope: scope}

      {:ok, _, [%NextTrackStarted{} = event]} = CommandBus.apply(command)

      session = ListeningSession.get(event.session_id)
      assert session.current_track_id == Enum.at(session.album.tracks, 1).id

      command = %SkipPreviousTrackListeningSession{session_id: event.session_id, scope: scope}

      {:ok, _, [%PreviousTrackStarted{} = event]} = CommandBus.apply(command)

      session = ListeningSession.get(event.session_id)
      assert session.current_track_id == Enum.at(session.album.tracks, 0).id

      command = %SkipPreviousTrackListeningSession{session_id: event.session_id, scope: scope}

      {:error, _} = CommandBus.apply(command)
    end
  end

  describe "handle/1 - StopListeningSession" do
    @tag :wip
    test "successfully creates session and generate a report" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      album = album_fixture()

      expect(TwitchApi, :cancel_all_subscriptions, fn %Scope{user: ^user} -> {:ok, []} end)
      expect(TwitchApi, :subscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)
      expect(TwitchApi, :cancel_all_subscriptions, fn %Scope{user: ^user} -> {:ok, []} end)

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)
      expect(SpotifyApi, :devices, 2, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track001"} end)
      expect(SpotifyApi, :pause_playback, fn _ -> {:ok, :success} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user},
                                               "Welcome to the premiere of Sample Album by Sample Artist",
                                               0 ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "(1/2) Track One", 0 -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !", 0 -> :ok end)

      expect(TwitchApi, :send_chat_message, fn _scope,
                                               "You can retrieve all your notes by registering to https://premiere-ecoute.fr/ using your Twitch account",
                                               0 ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn _scope, "The premiere of Sample Album is over", 0 -> :ok end)

      expect(TwitchApi, :send_chat_message, fn _scope,
                                               "You can retrieve all your notes by registering to https://premiere-ecoute.fr/ using your Twitch account",
                                               0 ->
        :ok
      end)

      command = %PrepareListeningSession{
        source: :album,
        user_id: user.id,
        album_id: album.album_id
      }

      {:ok, _, [%SessionPrepared{} = event]} = CommandBus.apply(command)

      command = %StartListeningSession{source: :album, session_id: event.session_id, scope: scope}

      {:ok, _, [%SessionStarted{} = event, %NextTrackStarted{}]} = CommandBus.apply(command)

      command = %StopListeningSession{session_id: event.session_id, scope: scope}

      {:ok, session, [%SessionStopped{}]} = CommandBus.apply(command)

      report = Report.get_by(session_id: session.id)

      assert session.status == :stopped
      assert session.current_track == nil

      assert %PremiereEcoute.Sessions.Retrospective.Report{
               polls: [],
               session_id: session_id,
               session_summary: %{
                 "unique_votes" => 0,
                 "unique_voters" => 0,
                 "streamer_score" => nil,
                 "tracks_rated" => 0,
                 "viewer_score" => nil
               },
               track_summaries: [],
               votes: []
             } = report

      assert session_id == session.id
    end
  end
end
