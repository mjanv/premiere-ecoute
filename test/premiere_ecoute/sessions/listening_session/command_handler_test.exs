defmodule PremiereEcoute.Sessions.ListeningSession.CommandHandlerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.CaptureCurrentTrackListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.CloseVoteWindowListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.Commands.OpenVoteWindowListeningSession
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
  alias PremiereEcoute.Sessions.ListeningSession.Events.TrackCaptured
  alias PremiereEcoute.Sessions.ListeningSession.Events.VoteWindowClosed
  alias PremiereEcoute.Sessions.ListeningSession.Events.VoteWindowOpened
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcouteCore.CommandBus

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.Streaming.TwitchApi.Mock, as: TwitchApi

  describe "handle/1 - PrepareListeningSession" do
    test "successfully creates album session and returns SessionPrepared event" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      album = album_fixture()

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)

      command = %PrepareListeningSession{
        source: :album,
        user_id: user.id,
        album_id: Map.get(album.provider_ids, :spotify)
      }

      {:ok, session, [%SessionPrepared{}]} = CommandBus.apply(command)

      assert session.user_id == user.id
      assert session.status == :preparing

      assert Map.get(session.album.provider_ids, :spotify) == "album123"
      assert session.album.name == "Sample Album"
      assert session.album.artist.name == "Sample Artist"
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
        provider_ids: %{spotify: album_id},
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
        album_id: Map.get(album.provider_ids, :spotify)
      }

      {:ok, _, [event1]} = CommandBus.apply(command)
      {:ok, _, [event2]} = CommandBus.apply(command)

      assert event1.session_id != event2.session_id
    end

    test "successfully creates track session and returns SessionPrepared event" do
      user = user_fixture()
      single = single_fixture()

      expect(SpotifyApi, :get_single, fn _ -> {:ok, single} end)

      command = %PrepareListeningSession{
        source: :track,
        user_id: user.id,
        track_id: Map.get(single.provider_ids, :spotify)
      }

      {:ok, session, [%SessionPrepared{} = event]} = CommandBus.apply(command)

      assert session.user_id == user.id
      assert session.status == :preparing
      assert session.source == :track
      assert session.single.provider_ids == single.provider_ids
      assert session.single.name == single.name
      assert session.single.artist == single.artist
      assert event.single_id == session.single_id
    end

    test "returns SessionNotPrepared when SpotifyApi get_single fails" do
      user_id = 1
      track_id = "invalid_track"

      expect(SpotifyApi, :get_single, fn ^track_id -> {:error, :not_found} end)

      command = %PrepareListeningSession{
        source: :track,
        user_id: user_id,
        track_id: track_id
      }

      {:error, [%SessionNotPrepared{} = event]} = CommandBus.apply(command)

      assert event.user_id == user_id
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

      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :toggle_playback_shuffle, fn %Scope{user: ^user}, false -> {:ok, :success} end)
      expect(SpotifyApi, :set_repeat_mode, fn %Scope{user: ^user}, :off -> {:ok, :success} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "Welcome to the premiere of Sample Album by Sample Artist (2 tracks - 06:30)" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can vote between 0 and 10 included and without comma. The note is a single message or at the end of a message" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      command = %PrepareListeningSession{
        source: :album,
        user_id: user.id,
        album_id: Map.get(album.provider_ids, :spotify)
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
      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(SpotifyApi, :get_album, 2, fn _ -> {:ok, album} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :toggle_playback_shuffle, fn %Scope{user: ^user}, false -> {:ok, :success} end)
      expect(SpotifyApi, :set_repeat_mode, fn %Scope{user: ^user}, :off -> {:ok, :success} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "Welcome to the premiere of Sample Album by Sample Artist (2 tracks - 06:30)" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can vote between 0 and 10 included and without comma. The note is a single message or at the end of a message" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      # Second session setup - partial expectations (fails before most API calls)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      # Prepare and start first session
      {:ok, _, [%SessionPrepared{} = event1]} =
        CommandBus.apply(%PrepareListeningSession{
          source: :album,
          user_id: user.id,
          album_id: Map.get(album.provider_ids, :spotify)
        })

      {:ok, _, [%SessionStarted{}]} =
        CommandBus.apply(%StartListeningSession{source: :album, session_id: event1.session_id, scope: scope})

      # Prepare second session
      {:ok, _, [%SessionPrepared{} = event2]} =
        CommandBus.apply(%PrepareListeningSession{
          source: :album,
          user_id: user.id,
          album_id: Map.get(album.provider_ids, :spotify)
        })

      # Try to start second session - should fail
      {:error, reason} = CommandBus.apply(%StartListeningSession{source: :album, session_id: event2.session_id, scope: scope})

      assert reason == "You already have an active listening session"
    end

    test "successfully start a prepared playlist session and returns SessionStarted event" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      playlist = playlist_fixture()

      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(SpotifyApi, :get_playlist, fn _ -> {:ok, playlist} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :toggle_playback_shuffle, fn %Scope{user: ^user}, false -> {:ok, :success} end)
      expect(SpotifyApi, :set_repeat_mode, fn %Scope{user: ^user}, :off -> {:ok, :success} end)

      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:playlist:2gW4sqiC2OXZLe9m0yDQX7"} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Welcome to the premiere of FLONFLON MUSIC FRIDAY by Flonflon" -> :ok end)

      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !" -> :ok end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can vote between 0 and 10 included and without comma. The note is a single message or at the end of a message" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
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

  describe "handle/1 - StartListeningSession :track" do
    test "successfully starts a track session and returns SessionStarted event" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      single = single_fixture()

      expect(SpotifyApi, :get_single, fn _ -> {:ok, single} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track123"} end)

      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "Welcome to the premiere of Sample Track by Sample Artist" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !" -> :ok end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can vote between 0 and 10 included and without comma. The note is a single message or at the end of a message" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{
          source: :track,
          user_id: user.id,
          track_id: Map.get(single.provider_ids, :spotify)
        })

      {:ok, _, [%SessionStarted{} = event]} =
        CommandBus.apply(%StartListeningSession{source: :track, session_id: prepared.session_id, scope: scope})

      session = ListeningSession.get(event.session_id)

      assert session.status == :active
      assert event.source == :track

      assert Report.get_by(session_id: session.id) != nil
    end

    test "fails when no active Spotify device for track session" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      single = single_fixture()

      expect(SpotifyApi, :get_single, fn _ -> {:ok, single} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => false}]} end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{
          source: :track,
          user_id: user.id,
          track_id: Map.get(single.provider_ids, :spotify)
        })

      {:error, reason} =
        CommandBus.apply(%StartListeningSession{source: :track, session_id: prepared.session_id, scope: scope})

      assert reason == "No Spotify active device detected"
    end
  end

  describe "handle/1 - SkipNextTrackListeningSession" do
    test "successfully skip to the next track until none are left and returns NextTrackStarted event" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      album = album_fixture()

      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :toggle_playback_shuffle, fn %Scope{user: ^user}, false -> {:ok, :success} end)
      expect(SpotifyApi, :set_repeat_mode, fn %Scope{user: ^user}, :off -> {:ok, :success} end)
      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track001"} end)
      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track002"} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "Welcome to the premiere of Sample Album by Sample Artist (2 tracks - 06:30)" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can vote between 0 and 10 included and without comma. The note is a single message or at the end of a message" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "(1/2) Track One (03:30)" -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !" -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "(2/2) Track Two (03:00)" -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !" -> :ok end)

      command = %PrepareListeningSession{
        source: :album,
        user_id: user.id,
        album_id: Map.get(album.provider_ids, :spotify)
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

  describe "handle/1 - SkipNextTrackListeningSession :playlist" do
    test "advances current_playlist_track and emits NextTrackStarted with the track" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      playlist = playlist_fixture()

      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(SpotifyApi, :get_playlist, fn _ -> {:ok, playlist} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :toggle_playback_shuffle, fn %Scope{user: ^user}, false -> {:ok, :success} end)
      expect(SpotifyApi, :set_repeat_mode, fn %Scope{user: ^user}, :off -> {:ok, :success} end)

      # start: playlist context; skip: individual track
      expect(SpotifyApi, :start_resume_playback, 2, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:4gVsKMMK0f8dweHL7Vm9HC"} end)

      # SessionStarted schedules: open_playlist ("Votes are open!") + send_promo_message (promo)
      # NextTrackStarted schedules: open_playlist ("Votes are open!")
      # Total: 2x "Votes are open!", 1x promo — stub accepts any message in any order
      stub(TwitchApi, :send_chat_message, fn %Scope{}, _ -> :ok end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{source: :playlist, user_id: user.id, playlist_id: playlist.playlist_id})

      {:ok, _, [%SessionStarted{} = started]} =
        CommandBus.apply(%StartListeningSession{source: :playlist, session_id: prepared.session_id, scope: scope})

      session = ListeningSession.get(started.session_id)
      assert session.current_playlist_track_id == nil

      {:ok, session, [%NextTrackStarted{source: :playlist, track: track}]} =
        CommandBus.apply(%SkipNextTrackListeningSession{source: :playlist, session_id: started.session_id, scope: scope})

      assert session.current_playlist_track_id != nil
      assert track != nil
      assert track.name == "Mind Loaded (feat. Caroline Polachek, Lorde & Mustafa)"
    end

    test "returns error when all playlist tracks are exhausted" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      playlist = playlist_fixture()

      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(SpotifyApi, :get_playlist, fn _ -> {:ok, playlist} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :toggle_playback_shuffle, fn %Scope{user: ^user}, false -> {:ok, :success} end)
      expect(SpotifyApi, :set_repeat_mode, fn %Scope{user: ^user}, :off -> {:ok, :success} end)

      # start: playlist context; skip: individual track
      expect(SpotifyApi, :start_resume_playback, 2, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:4gVsKMMK0f8dweHL7Vm9HC"} end)

      # SessionStarted schedules: open_playlist ("Votes are open!") + send_promo_message (promo)
      # NextTrackStarted schedules: open_playlist ("Votes are open!")
      # Total: 2x "Votes are open!", 1x promo — stub accepts any message in any order
      stub(TwitchApi, :send_chat_message, fn %Scope{}, _ -> :ok end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{source: :playlist, user_id: user.id, playlist_id: playlist.playlist_id})

      {:ok, _, [%SessionStarted{} = started]} =
        CommandBus.apply(%StartListeningSession{source: :playlist, session_id: prepared.session_id, scope: scope})

      # Playlist fixture has 1 track — skip once to reach end
      {:ok, _, [%NextTrackStarted{}]} =
        CommandBus.apply(%SkipNextTrackListeningSession{source: :playlist, session_id: started.session_id, scope: scope})

      # Second skip — no tracks left
      {:error, _} =
        CommandBus.apply(%SkipNextTrackListeningSession{source: :playlist, session_id: started.session_id, scope: scope})
    end
  end

  describe "handle/1 - SkipPreviousTrackListeningSession" do
    test "successfully skip to the previous track until none are left and returns PreviousTrackStarted event" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      album = album_fixture()

      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :toggle_playback_shuffle, fn %Scope{user: ^user}, false -> {:ok, :success} end)
      expect(SpotifyApi, :set_repeat_mode, fn %Scope{user: ^user}, :off -> {:ok, :success} end)
      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track001"} end)
      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track002"} end)
      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track001"} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "Welcome to the premiere of Sample Album by Sample Artist (2 tracks - 06:30)" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can vote between 0 and 10 included and without comma. The note is a single message or at the end of a message" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "(1/2) Track One (03:30)" -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !" -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "(2/2) Track Two (03:00)" -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !" -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "(1/2) Track One (03:30)" -> :ok end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !" -> :ok end)

      command = %PrepareListeningSession{
        source: :album,
        user_id: user.id,
        album_id: Map.get(album.provider_ids, :spotify)
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
    test "successfully creates session and generate a report" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      album = album_fixture()

      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)
      expect(TwitchApi, :unsubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, UUID.uuid4()} end)

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)
      expect(SpotifyApi, :devices, 2, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :toggle_playback_shuffle, fn %Scope{user: ^user}, false -> {:ok, :success} end)
      expect(SpotifyApi, :set_repeat_mode, fn %Scope{user: ^user}, :off -> {:ok, :success} end)
      expect(SpotifyApi, :pause_playback, fn _ -> {:ok, :success} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{user: ^user}, "Welcome to the premiere of Sample Album by Sample Artist (2 tracks - 06:30)" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can vote between 0 and 10 included and without comma. The note is a single message or at the end of a message" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn _scope,
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn _scope, "The premiere of Sample Album is over" -> :ok end)

      expect(TwitchApi, :send_chat_message, fn _scope,
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      command = %PrepareListeningSession{
        source: :album,
        user_id: user.id,
        album_id: Map.get(album.provider_ids, :spotify)
      }

      {:ok, _, [%SessionPrepared{} = event]} = CommandBus.apply(command)

      command = %StartListeningSession{source: :album, session_id: event.session_id, scope: scope}

      {:ok, _, [%SessionStarted{} = event]} = CommandBus.apply(command)

      command = %StopListeningSession{source: :album, session_id: event.session_id, scope: scope}

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

  describe "handle/1 - StopListeningSession :playlist" do
    test "stops playlist session, sends playlist title in stop message, pauses Spotify" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      playlist = playlist_fixture()

      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)
      expect(TwitchApi, :unsubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, UUID.uuid4()} end)

      expect(SpotifyApi, :get_playlist, fn _ -> {:ok, playlist} end)
      expect(SpotifyApi, :devices, 2, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :toggle_playback_shuffle, fn %Scope{user: ^user}, false -> {:ok, :success} end)
      expect(SpotifyApi, :set_repeat_mode, fn %Scope{user: ^user}, :off -> {:ok, :success} end)

      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:playlist:2gW4sqiC2OXZLe9m0yDQX7"} end)

      expect(SpotifyApi, :pause_playback, fn _ -> {:ok, :success} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Welcome to the premiere of FLONFLON MUSIC FRIDAY by Flonflon" -> :ok end)

      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !" -> :ok end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can vote between 0 and 10 included and without comma. The note is a single message or at the end of a message" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{}, "The premiere of FLONFLON MUSIC FRIDAY is over" -> :ok end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{source: :playlist, user_id: user.id, playlist_id: playlist.playlist_id})

      {:ok, _, [%SessionStarted{} = started]} =
        CommandBus.apply(%StartListeningSession{source: :playlist, session_id: prepared.session_id, scope: scope})

      {:ok, session, [%SessionStopped{}]} =
        CommandBus.apply(%StopListeningSession{source: :playlist, session_id: started.session_id, scope: scope})

      assert session.status == :stopped
    end
  end

  describe "handle/1 - StopListeningSession :track" do
    test "stops track session without pausing Spotify and sends end chat message" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      single = single_fixture()

      expect(SpotifyApi, :get_single, fn _ -> {:ok, single} end)
      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :start_resume_playback, fn %Scope{user: ^user}, _ -> {:ok, "spotify:track:track123"} end)

      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Welcome to the premiere of Sample Track by Sample Artist" -> :ok end)

      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Votes are open !" -> :ok end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can vote between 0 and 10 included and without comma. The note is a single message or at the end of a message" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      # Stop messages
      expect(TwitchApi, :send_chat_message, fn %Scope{}, "Sample Track by Sample Artist is over" -> :ok end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{
          source: :track,
          user_id: user.id,
          track_id: Map.get(single.provider_ids, :spotify)
        })

      {:ok, _, [%SessionStarted{} = started]} =
        CommandBus.apply(%StartListeningSession{source: :track, session_id: prepared.session_id, scope: scope})

      {:ok, session, [%SessionStopped{}]} =
        CommandBus.apply(%StopListeningSession{source: :track, session_id: started.session_id, scope: scope})

      assert session.status == :stopped
    end
  end

  describe "handle/1 - PrepareListeningSession :free" do
    test "creates a free session with chat vote_mode when vote_options > 5" do
      user = user_fixture()

      command = %PrepareListeningSession{
        source: :free,
        user_id: user.id,
        vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
      }

      {:ok, session, [%SessionPrepared{} = event]} = CommandBus.apply(command)

      assert session.source == :free
      assert session.status == :preparing
      assert session.vote_mode == :chat
      assert session.name == "Free session"
      assert event.source == :free
      assert event.session_id == session.id
      assert event.user_id == user.id
    end

    test "creates a free session with poll vote_mode when explicitly set" do
      user = user_fixture()

      command = %PrepareListeningSession{
        source: :free,
        user_id: user.id,
        vote_options: ["1", "2", "3", "4", "5"],
        vote_mode: :poll
      }

      {:ok, session, [%SessionPrepared{}]} = CommandBus.apply(command)

      assert session.vote_mode == :poll
    end

    test "uses custom name when provided" do
      user = user_fixture()

      command = %PrepareListeningSession{
        source: :free,
        user_id: user.id,
        name: "My Friday stream"
      }

      {:ok, session, [%SessionPrepared{}]} = CommandBus.apply(command)

      assert session.name == "My Friday stream"
    end

    test "defaults to 'Free session' when no name provided" do
      user = user_fixture()

      {:ok, session, [%SessionPrepared{}]} =
        CommandBus.apply(%PrepareListeningSession{source: :free, user_id: user.id})

      assert session.name == "Free session"
    end
  end

  describe "handle/1 - StartListeningSession :free" do
    test "starts free session: checks Spotify device, subscribes Twitch, generates report" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)

      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{source: :free, user_id: user.id})

      {:ok, session, [%SessionStarted{} = event]} =
        CommandBus.apply(%StartListeningSession{source: :free, session_id: prepared.session_id, scope: scope})

      assert session.status == :active
      assert event.source == :free
      assert Report.get_by(session_id: session.id) != nil
    end

    test "fails when no active Spotify device" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)

      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => false}]} end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{source: :free, user_id: user.id})

      {:error, reason} =
        CommandBus.apply(%StartListeningSession{source: :free, session_id: prepared.session_id, scope: scope})

      assert reason == "No Spotify active device detected"
    end
  end

  describe "handle/1 - CaptureCurrentTrackListeningSession" do
    test "captures currently playing track and updates session single_id" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      single = single_fixture()

      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, _ -> :ok end)

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %{} ->
        {:ok, %{"item" => %{"id" => Map.get(single.provider_ids, :spotify)}, "is_playing" => true}}
      end)

      expect(SpotifyApi, :get_single, fn _track_id -> {:ok, single} end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{source: :free, user_id: user.id})

      {:ok, _, [%SessionStarted{} = started]} =
        CommandBus.apply(%StartListeningSession{source: :free, session_id: prepared.session_id, scope: scope})

      {:ok, session, [%TrackCaptured{} = event]} =
        CommandBus.apply(%CaptureCurrentTrackListeningSession{session_id: started.session_id, scope: scope})

      assert session.single_id != nil
      assert event.track_name == single.name
      assert event.artist == single.artist
      assert event.single_id == session.single_id
    end

    test "returns error when nothing is playing on Spotify" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)

      expect(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)
      expect(TwitchApi, :send_chat_message, fn %Scope{}, _ -> :ok end)

      expect(SpotifyApi, :get_playback_state, fn %Scope{user: ^user}, %{} ->
        {:ok, %{"is_playing" => false}}
      end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{source: :free, user_id: user.id})

      {:ok, _, [%SessionStarted{} = started]} =
        CommandBus.apply(%StartListeningSession{source: :free, session_id: prepared.session_id, scope: scope})

      {:error, reason} =
        CommandBus.apply(%CaptureCurrentTrackListeningSession{session_id: started.session_id, scope: scope})

      assert reason == :no_active_playback
    end
  end

  describe "handle/1 - OpenVoteWindowListeningSession" do
    test "emits VoteWindowOpened with chat mode when session has a captured track" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      single = single_fixture()

      stub(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      stub(TwitchApi, :resubscribe, fn _, _ -> {:ok, %{}} end)
      stub(TwitchApi, :send_chat_message, fn _, _ -> :ok end)

      expect(SpotifyApi, :get_playback_state, fn _, _ ->
        {:ok, %{"item" => %{"id" => Map.get(single.provider_ids, :spotify)}, "is_playing" => true}}
      end)

      expect(SpotifyApi, :get_single, fn _ -> {:ok, single} end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{
          source: :free,
          user_id: user.id,
          vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
        })

      {:ok, _, [%SessionStarted{} = started]} =
        CommandBus.apply(%StartListeningSession{source: :free, session_id: prepared.session_id, scope: scope})

      {:ok, _, _} =
        CommandBus.apply(%CaptureCurrentTrackListeningSession{session_id: started.session_id, scope: scope})

      {:ok, session, [%VoteWindowOpened{} = event]} =
        CommandBus.apply(%OpenVoteWindowListeningSession{session_id: started.session_id, scope: scope})

      assert event.vote_mode == :chat
      assert event.track_id == session.single_id
    end

    test "returns error when session has no captured track" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)

      stub(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      stub(TwitchApi, :resubscribe, fn _, _ -> {:ok, %{}} end)
      stub(TwitchApi, :send_chat_message, fn _, _ -> :ok end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{source: :free, user_id: user.id})

      {:ok, _, [%SessionStarted{} = started]} =
        CommandBus.apply(%StartListeningSession{source: :free, session_id: prepared.session_id, scope: scope})

      {:error, reason} =
        CommandBus.apply(%OpenVoteWindowListeningSession{session_id: started.session_id, scope: scope})

      assert reason == :no_captured_track
    end
  end

  describe "handle/1 - CloseVoteWindowListeningSession" do
    test "emits VoteWindowClosed with correct vote_mode" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)
      single = single_fixture()

      stub(SpotifyApi, :devices, fn _ -> {:ok, [%{"is_active" => true}]} end)
      stub(TwitchApi, :resubscribe, fn _, _ -> {:ok, %{}} end)
      stub(TwitchApi, :send_chat_message, fn _, _ -> :ok end)

      expect(SpotifyApi, :get_playback_state, fn _, _ ->
        {:ok, %{"item" => %{"id" => Map.get(single.provider_ids, :spotify)}, "is_playing" => true}}
      end)

      expect(SpotifyApi, :get_single, fn _ -> {:ok, single} end)

      expect(TwitchApi, :create_poll, fn _, _ -> {:ok, %{"id" => "poll-123"}} end)
      expect(TwitchApi, :end_poll, fn _, "poll-123" -> {:ok, %{}} end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{
          source: :free,
          user_id: user.id,
          vote_options: ["1", "2", "3", "4", "5"],
          vote_mode: :poll
        })

      {:ok, _, [%SessionStarted{} = started]} =
        CommandBus.apply(%StartListeningSession{source: :free, session_id: prepared.session_id, scope: scope})

      {:ok, _, _} =
        CommandBus.apply(%CaptureCurrentTrackListeningSession{session_id: started.session_id, scope: scope})

      {:ok, _, _} =
        CommandBus.apply(%OpenVoteWindowListeningSession{session_id: started.session_id, scope: scope})

      {:ok, _session, [%VoteWindowClosed{} = event]} =
        CommandBus.apply(%CloseVoteWindowListeningSession{session_id: started.session_id, scope: scope})

      assert event.vote_mode == :poll
    end
  end

  describe "handle/1 - StopListeningSession :free" do
    test "stops free session, sends end message, pauses Spotify, unsubscribes Twitch" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = user_scope_fixture(user)

      expect(SpotifyApi, :devices, 2, fn _ -> {:ok, [%{"is_active" => true}]} end)
      expect(SpotifyApi, :pause_playback, fn _ -> {:ok, :success} end)
      expect(TwitchApi, :resubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, %{}} end)
      expect(TwitchApi, :unsubscribe, fn %Scope{user: ^user}, "channel.chat.message" -> {:ok, UUID.uuid4()} end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      expect(TwitchApi, :send_chat_message, fn %Scope{}, "The free session Free session is over" -> :ok end)

      expect(TwitchApi, :send_chat_message, fn %Scope{},
                                               "You can retrieve all your notes by registering to premiere-ecoute.fr using your Twitch account" ->
        :ok
      end)

      {:ok, _, [%SessionPrepared{} = prepared]} =
        CommandBus.apply(%PrepareListeningSession{source: :free, user_id: user.id})

      {:ok, _, [%SessionStarted{} = started]} =
        CommandBus.apply(%StartListeningSession{source: :free, session_id: prepared.session_id, scope: scope})

      {:ok, session, [%SessionStopped{}]} =
        CommandBus.apply(%StopListeningSession{source: :free, session_id: started.session_id, scope: scope})

      assert session.status == :stopped
    end
  end
end
