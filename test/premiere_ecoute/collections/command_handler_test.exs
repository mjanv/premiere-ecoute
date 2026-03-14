defmodule PremiereEcoute.Collections.CollectionSession.CommandHandlerTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Collections.CollectionSession.Commands.CloseVoteWindow
  alias PremiereEcoute.Collections.CollectionSession.Commands.CompleteCollectionSession
  alias PremiereEcoute.Collections.CollectionSession.Commands.DecideTrack
  alias PremiereEcoute.Collections.CollectionSession.Commands.OpenVoteWindow
  alias PremiereEcoute.Collections.CollectionSession.Commands.PrepareCollectionSession
  alias PremiereEcoute.Collections.CollectionSession.Commands.StartCollectionSession
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionCompleted
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionPrepared
  alias PremiereEcoute.Collections.CollectionSession.Events.CollectionSessionStarted
  alias PremiereEcoute.Collections.CollectionSession.Events.TrackDecided
  alias PremiereEcoute.Collections.CollectionSession.Events.VoteWindowClosed
  alias PremiereEcoute.Collections.CollectionSession.Events.VoteWindowOpened
  alias PremiereEcouteCore.Cache
  alias PremiereEcouteCore.CommandBus

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.Streaming.TwitchApi.Mock, as: TwitchApi

  describe "handle/1 - PrepareCollectionSession" do
    test "creates session and returns CollectionSessionPrepared event" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = Scope.for_user(user)
      origin = collection_library_playlist_fixture(user)
      destination = collection_library_playlist_fixture(user)

      command = %PrepareCollectionSession{
        scope: scope,
        origin_playlist_id: origin.id,
        destination_playlist_id: destination.id
      }

      {:ok, session, [%CollectionSessionPrepared{} = event]} = CommandBus.apply(command)

      assert session.status == :pending
      assert session.origin_playlist_id == origin.id
      assert session.destination_playlist_id == destination.id
      assert event.session_id == session.id
      assert event.user_id == user.id
    end
  end

  describe "handle/1 - StartCollectionSession" do
    test "fetches playlist, stores tracks in cache, starts session, emits event" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = Scope.for_user(user)
      playlist = playlist_fixture()
      session = collection_session_fixture(user)

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)
      expect(TwitchApi, :resubscribe, fn _scope, "channel.chat.message" -> {:ok, %{}} end)

      command = %StartCollectionSession{session_id: session.id, scope: scope}
      {:ok, started, [%CollectionSessionStarted{} = event]} = CommandBus.apply(command)

      assert started.status == :active
      assert event.session_id == session.id
      assert event.user_id == user.id

      {:ok, cached} = Cache.get(:collections, user.twitch.user_id)
      assert is_list(cached.tracks)
      assert cached.session_id == session.id
    end
  end

  describe "handle/1 - OpenVoteWindow" do
    test "stores track ids in cache and emits VoteWindowOpened" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = Scope.for_user(user)
      playlist = playlist_fixture()
      session = collection_session_fixture(user)

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)
      expect(TwitchApi, :resubscribe, fn _scope, "channel.chat.message" -> {:ok, %{}} end)
      {:ok, session, _} = CommandBus.apply(%StartCollectionSession{session_id: session.id, scope: scope})

      Oban.Testing.with_testing_mode(:manual, fn ->
        command = %OpenVoteWindow{
          session_id: session.id,
          scope: scope,
          track_id: "track1",
          duel_track_id: nil,
          selection_mode: :viewer_vote,
          vote_duration: 30
        }

        {:ok, _session, [%VoteWindowOpened{} = event]} = CommandBus.apply(command)

        assert event.track_id == "track1"
        assert event.vote_duration == 30
        assert event.selection_mode == :viewer_vote

        {:ok, cached} = Cache.get(:collections, user.twitch.user_id)
        assert cached.active_track_id == "track1"
        assert cached.votes_a == 0
        assert cached.votes_b == 0
      end)
    end

    test "stores duel track ids in cache" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = Scope.for_user(user)
      playlist = playlist_fixture()
      session = collection_session_fixture(user)

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)
      expect(TwitchApi, :resubscribe, fn _scope, "channel.chat.message" -> {:ok, %{}} end)
      {:ok, session, _} = CommandBus.apply(%StartCollectionSession{session_id: session.id, scope: scope})

      Oban.Testing.with_testing_mode(:manual, fn ->
        command = %OpenVoteWindow{session_id: session.id, scope: scope, track_id: "trackA", duel_track_id: "trackB"}
        {:ok, _session, [%VoteWindowOpened{} = event]} = CommandBus.apply(command)

        assert event.track_id == "trackA"
        assert event.duel_track_id == "trackB"

        {:ok, cached} = Cache.get(:collections, user.twitch.user_id)
        assert cached.active_track_id == "trackA"
        assert cached.duel_track_id == "trackB"
      end)
    end
  end

  describe "handle/1 - CloseVoteWindow" do
    test "removes vote state from cache and emits VoteWindowClosed" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = Scope.for_user(user)
      playlist = playlist_fixture()
      session = collection_session_fixture(user)

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)
      expect(TwitchApi, :resubscribe, fn _scope, "channel.chat.message" -> {:ok, %{}} end)
      {:ok, session, _} = CommandBus.apply(%StartCollectionSession{session_id: session.id, scope: scope})

      Oban.Testing.with_testing_mode(:manual, fn ->
        CommandBus.apply(%OpenVoteWindow{
          session_id: session.id,
          scope: scope,
          track_id: "track1",
          duel_track_id: nil,
          selection_mode: :viewer_vote,
          vote_duration: 30
        })
      end)

      command = %CloseVoteWindow{session_id: session.id, scope: scope}
      {:ok, _session, [%VoteWindowClosed{} = event]} = CommandBus.apply(command)

      assert event.track_id == "track1"

      {:ok, cached} = Cache.get(:collections, user.twitch.user_id)
      refute Map.has_key?(cached, :active_track_id)
      refute Map.has_key?(cached, :votes_a)
    end
  end

  describe "handle/1 - DecideTrack in duel mode" do
    test "stores winner as :kept and loser as :rejected in session arrays" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = Scope.for_user(user)
      playlist = playlist_fixture()
      session = collection_session_fixture(user)

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)
      expect(TwitchApi, :resubscribe, fn _scope, "channel.chat.message" -> {:ok, %{}} end)
      {:ok, session, _} = CommandBus.apply(%StartCollectionSession{session_id: session.id, scope: scope})

      command = %DecideTrack{
        session_id: session.id,
        scope: scope,
        track_id: "winner_id",
        decision: :kept,
        duel_track_id: "loser_id"
      }

      {:ok, advanced, _events} = CommandBus.apply(command)

      assert "winner_id" in advanced.kept
      assert "loser_id" in advanced.rejected
      assert advanced.current_index == 2
    end

    test "when picking B, the LiveView remaps so B arrives as primary :kept with A as duel loser :rejected" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = Scope.for_user(user)
      playlist = playlist_fixture()
      session = collection_session_fixture(user)

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)
      expect(TwitchApi, :resubscribe, fn _scope, "channel.chat.message" -> {:ok, %{}} end)
      {:ok, session, _} = CommandBus.apply(%StartCollectionSession{session_id: session.id, scope: scope})

      # AIDEV-NOTE: LiveView remaps "Pick B" before sending: primary = B (kept), loser = A (rejected)
      command = %DecideTrack{
        session_id: session.id,
        scope: scope,
        track_id: "track_b_id",
        decision: :kept,
        duel_track_id: "track_a_id"
      }

      {:ok, advanced, _events} = CommandBus.apply(command)

      assert "track_b_id" in advanced.kept
      assert "track_a_id" in advanced.rejected
    end
  end

  describe "handle/1 - DecideTrack" do
    test "records decision, advances index, emits TrackDecided" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = Scope.for_user(user)
      playlist = playlist_fixture()
      session = collection_session_fixture(user)

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)
      expect(TwitchApi, :resubscribe, fn _scope, "channel.chat.message" -> {:ok, %{}} end)
      {:ok, session, _} = CommandBus.apply(%StartCollectionSession{session_id: session.id, scope: scope})

      command = %DecideTrack{
        session_id: session.id,
        scope: scope,
        track_id: "track1",
        decision: :kept,
        duel_track_id: nil
      }

      {:ok, advanced, [%TrackDecided{} = event]} = CommandBus.apply(command)

      assert advanced.current_index == 1
      assert event.track_id == "track1"
      assert event.decision == :kept
    end

    test "advances by 2 for duel decisions" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = Scope.for_user(user)
      playlist = playlist_fixture()
      session = collection_session_fixture(user)

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)
      expect(TwitchApi, :resubscribe, fn _scope, "channel.chat.message" -> {:ok, %{}} end)
      {:ok, session, _} = CommandBus.apply(%StartCollectionSession{session_id: session.id, scope: scope})

      command = %DecideTrack{
        session_id: session.id,
        scope: scope,
        track_id: "trackA",
        decision: :kept,
        duel_track_id: "trackB"
      }

      {:ok, advanced, [%TrackDecided{}]} = CommandBus.apply(command)
      assert advanced.current_index == 2
    end
  end

  describe "handle/1 - CompleteCollectionSession" do
    test "syncs kept tracks to spotify, deletes cache, completes session" do
      user = user_fixture(%{twitch: %{user_id: "1234"}, spotify: %{user_id: "sp1"}})
      scope = Scope.for_user(user)
      playlist = playlist_fixture()
      session = collection_session_fixture(user)

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)
      expect(TwitchApi, :resubscribe, fn _scope, "channel.chat.message" -> {:ok, %{}} end)
      {:ok, session, _} = CommandBus.apply(%StartCollectionSession{session_id: session.id, scope: scope})

      # Record a kept decision
      CommandBus.apply(%DecideTrack{
        session_id: session.id,
        scope: scope,
        track_id: "track1",
        decision: :kept,
        duel_track_id: nil
      })

      expect(SpotifyApi, :add_items_to_playlist, fn _scope, _playlist_id, _tracks -> {:ok, %{}} end)
      expect(TwitchApi, :unsubscribe, fn _scope, "channel.chat.message" -> {:ok, "unsubscribed"} end)

      command = %CompleteCollectionSession{session_id: session.id, scope: scope}
      {:ok, completed, [%CollectionSessionCompleted{} = event]} = CommandBus.apply(command)

      assert completed.status == :completed
      assert event.kept_count == 1
      assert {:ok, nil} = Cache.get(:collections, user.twitch.user_id)
    end

    test "completes session with no kept tracks without calling spotify" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      scope = Scope.for_user(user)
      playlist = playlist_fixture()
      session = collection_session_fixture(user)

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)
      expect(TwitchApi, :resubscribe, fn _scope, "channel.chat.message" -> {:ok, %{}} end)
      {:ok, session, _} = CommandBus.apply(%StartCollectionSession{session_id: session.id, scope: scope})

      # Record a rejected decision (not kept)
      CommandBus.apply(%DecideTrack{
        session_id: session.id,
        scope: scope,
        track_id: "track1",
        decision: :rejected,
        duel_track_id: nil
      })

      expect(TwitchApi, :unsubscribe, fn _scope, "channel.chat.message" -> {:ok, "unsubscribed"} end)

      command = %CompleteCollectionSession{session_id: session.id, scope: scope}
      {:ok, completed, [%CollectionSessionCompleted{} = event]} = CommandBus.apply(command)

      assert completed.status == :completed
      assert event.kept_count == 0
    end

    test "removes kept tracks from origin playlist when remove_kept is true" do
      user = user_fixture(%{twitch: %{user_id: "1234"}, spotify: %{user_id: "sp1"}})
      scope = Scope.for_user(user)
      playlist = playlist_fixture()
      session = collection_session_fixture(user)

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)
      expect(TwitchApi, :resubscribe, fn _scope, "channel.chat.message" -> {:ok, %{}} end)
      {:ok, session, _} = CommandBus.apply(%StartCollectionSession{session_id: session.id, scope: scope})

      CommandBus.apply(%DecideTrack{
        session_id: session.id,
        scope: scope,
        track_id: "kept_track",
        decision: :kept,
        duel_track_id: nil
      })

      expect(SpotifyApi, :add_items_to_playlist, fn _scope, _id, _tracks -> {:ok, %{}} end)
      expect(TwitchApi, :unsubscribe, fn _scope, "channel.chat.message" -> {:ok, "unsubscribed"} end)

      expect(SpotifyApi, :remove_playlist_items, fn _scope, playlist_id, tracks ->
        assert playlist_id == session.origin_playlist.playlist_id
        assert Enum.map(tracks, fn t -> Map.get(t.provider_ids, :spotify) end) == ["kept_track"]
        {:ok, %{}}
      end)

      command = %CompleteCollectionSession{session_id: session.id, scope: scope, remove_kept: true}
      {:ok, completed, _events} = CommandBus.apply(command)
      assert completed.status == :completed
    end

    test "removes rejected tracks from origin playlist when remove_rejected is true" do
      user = user_fixture(%{twitch: %{user_id: "1234"}, spotify: %{user_id: "sp1"}})
      scope = Scope.for_user(user)
      playlist = playlist_fixture()
      session = collection_session_fixture(user)

      expect(SpotifyApi, :get_playlist, fn _id -> {:ok, playlist} end)
      expect(TwitchApi, :resubscribe, fn _scope, "channel.chat.message" -> {:ok, %{}} end)
      {:ok, session, _} = CommandBus.apply(%StartCollectionSession{session_id: session.id, scope: scope})

      CommandBus.apply(%DecideTrack{
        session_id: session.id,
        scope: scope,
        track_id: "kept_track",
        decision: :kept,
        duel_track_id: nil
      })

      CommandBus.apply(%DecideTrack{
        session_id: session.id,
        scope: scope,
        track_id: "rejected_track",
        decision: :rejected,
        duel_track_id: nil
      })

      expect(SpotifyApi, :add_items_to_playlist, fn _scope, _id, _tracks -> {:ok, %{}} end)
      expect(TwitchApi, :unsubscribe, fn _scope, "channel.chat.message" -> {:ok, "unsubscribed"} end)

      expect(SpotifyApi, :remove_playlist_items, fn _scope, playlist_id, tracks ->
        assert playlist_id == session.origin_playlist.playlist_id
        assert Enum.map(tracks, fn t -> Map.get(t.provider_ids, :spotify) end) == ["rejected_track"]
        {:ok, %{}}
      end)

      command = %CompleteCollectionSession{session_id: session.id, scope: scope, remove_rejected: true}
      {:ok, completed, _events} = CommandBus.apply(command)
      assert completed.status == :completed
    end
  end
end
