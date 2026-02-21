defmodule PremiereEcoute.Apis.Players.SpotifyPlayerTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.Players.SpotifyPlayer
  alias PremiereEcoute.Presence

  setup do
    user = user_fixture()
    scope = user_scope_fixture(user)

    start_supervised({Registry, keys: :unique, name: PremiereEcoute.Apis.Players.PlayerRegistry})

    {:ok, %{user: user, scope: scope}}
  end

  describe "handle_info(:poll, state)" do
    setup %{user: user} do
      scope = user_scope_fixture(user)

      # Join presence for the current process to simulate the player's own presence
      {:ok, phx_ref} = Presence.join(scope.user.id)

      initial_state = %{
        scope: scope,
        phx_ref: phx_ref,
        polls: 100,
        state: %{
          "is_playing" => false,
          "device" => %{"id" => "device123"},
          "item" => %{"uri" => "spotify:track:123", "duration_ms" => 180_000},
          "progress_ms" => 0
        }
      }

      {:ok, %{initial_state: initial_state}}
    end

    test "continues polling and updates state", %{initial_state: initial_state} do
      new_playback_state = %{
        "is_playing" => true,
        "device" => %{"id" => "device123"},
        "item" => %{"uri" => "spotify:track:456"},
        "progress_ms" => 1000
      }

      # Subscribe to the PubSub topic to receive broadcasts
      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "playback:#{initial_state.scope.user.id}")

      # Spawn a second process that also joins presence to prevent stop
      test_pid = self()

      spawn(fn ->
        {:ok, _ref} = Presence.join(initial_state.scope.user.id)
        # Keep process alive
        send(test_pid, :presence_joined)
        Process.sleep(:infinity)
      end)

      # Wait for the second presence to be tracked
      assert_receive :presence_joined

      expect(SpotifyApi, :get_playback_state, fn _scope, _old_state ->
        {:ok, new_playback_state}
      end)

      assert {:noreply, new_state} = SpotifyPlayer.handle_info(:poll, initial_state)

      assert new_state.state == new_playback_state
      assert_receive {:player, :start, _state}
    end

    test "stops normally when poll budget is exhausted", %{initial_state: initial_state} do
      exhausted_state = Map.put(initial_state, :polls, 0)

      assert {:stop, :normal, _state} = SpotifyPlayer.handle_info(:poll, exhausted_state)
    end

    test "stops when only one presence left", %{initial_state: initial_state} do
      expect(SpotifyApi, :get_playback_state, fn _scope, _old_state ->
        {:ok, initial_state.state}
      end)

      # Only the presence from setup exists, so it should stop
      assert {:stop, :normal, _state} = SpotifyPlayer.handle_info(:poll, initial_state)
    end

    test "stops with error when get_playback_state fails", %{initial_state: initial_state} do
      expect(SpotifyApi, :get_playback_state, fn _scope, _old_state ->
        {:error, "Spotify API error"}
      end)

      # Should stop with the error reason
      assert {:stop, {:error, "Spotify API error"}, _state} =
               SpotifyPlayer.handle_info(:poll, initial_state)
    end
  end

  describe "progress/1" do
    test "calculates progress percentage correctly" do
      state = %{
        "progress_ms" => 30_000,
        "item" => %{"duration_ms" => 180_000}
      }

      assert SpotifyPlayer.progress(state) == 16
    end

    test "handles zero duration gracefully" do
      state = %{
        "progress_ms" => 30_000,
        "item" => %{"duration_ms" => 0}
      }

      assert SpotifyPlayer.progress(state)
    end
  end

  describe "handle/2" do
    test "returns empty events for empty old state" do
      old_state = %{}
      new_state = %{"is_playing" => true, "item" => %{"uri" => "spotify:track:123"}}

      assert {:ok, ^new_state, []} = SpotifyPlayer.handle(old_state, new_state)
    end

    test "returns empty events when old device is nil" do
      old_state = %{"device" => nil}
      new_state = %{"is_playing" => true, "device" => %{"id" => "device123"}}

      assert {:ok, ^new_state, []} = SpotifyPlayer.handle(old_state, new_state)
    end

    test "returns :no_device event when new device is nil" do
      old_state = %{"device" => %{"id" => "device123"}, "is_playing" => true}
      new_state = %{"device" => nil}

      assert {:ok, ^new_state, [:no_device]} = SpotifyPlayer.handle(old_state, new_state)
    end

    test "detects playback start" do
      old_state = %{"is_playing" => false, "device" => %{"id" => "device123"}}
      new_state = %{"is_playing" => true, "device" => %{"id" => "device123"}}

      assert {:ok, ^new_state, [:start]} = SpotifyPlayer.handle(old_state, new_state)
    end

    test "detects playback stop" do
      old_state = %{"is_playing" => true, "device" => %{"id" => "device123"}}
      new_state = %{"is_playing" => false, "device" => %{"id" => "device123"}}

      assert {:ok, ^new_state, [:stop]} = SpotifyPlayer.handle(old_state, new_state)
    end

    test "detects new track" do
      old_state = %{
        "is_playing" => true,
        "device" => %{"id" => "device123"},
        "item" => %{"uri" => "spotify:track:123"}
      }

      new_state = %{
        "is_playing" => true,
        "device" => %{"id" => "device123"},
        "item" => %{"uri" => "spotify:track:456"}
      }

      assert {:ok, ^new_state, [:new_track]} = SpotifyPlayer.handle(old_state, new_state)
    end

    test "detects track start (0% to 1% progress)" do
      old_state = %{
        "progress_ms" => 0,
        "item" => %{"duration_ms" => 180_000},
        "device" => %{"id" => "device123"}
      }

      new_state = %{
        "progress_ms" => 2_000,
        "item" => %{"duration_ms" => 180_000},
        "device" => %{"id" => "device123"}
      }

      assert {:ok, ^new_state, [:start_track]} = SpotifyPlayer.handle(old_state, new_state)
    end

    test "detects track end (98% to 99% progress)" do
      old_state = %{
        "progress_ms" => 176_500,
        "item" => %{"duration_ms" => 180_000},
        "device" => %{"id" => "device123"}
      }

      new_state = %{
        "progress_ms" => 178_300,
        "item" => %{"duration_ms" => 180_000},
        "device" => %{"id" => "device123"}
      }

      assert {:ok, ^new_state, [:end_track]} = SpotifyPlayer.handle(old_state, new_state)
    end

    test "detects large skip (progress change > 5%)" do
      old_state = %{
        "progress_ms" => 18_000,
        "item" => %{"duration_ms" => 180_000},
        "device" => %{"id" => "device123"}
      }

      new_state = %{
        "progress_ms" => 90_000,
        "item" => %{"duration_ms" => 180_000},
        "device" => %{"id" => "device123"}
      }

      assert {:ok, ^new_state, [{:skip, 49}]} = SpotifyPlayer.handle(old_state, new_state)
    end

    test "detects normal progress update" do
      old_state = %{
        "progress_ms" => 18_000,
        "item" => %{"duration_ms" => 180_000},
        "device" => %{"id" => "device123"}
      }

      new_state = %{
        "progress_ms" => 27_000,
        "item" => %{"duration_ms" => 180_000},
        "device" => %{"id" => "device123"}
      }

      assert {:ok, ^new_state, [{:percent, 14}]} = SpotifyPlayer.handle(old_state, new_state)
    end

    test "returns empty events for backward progress or no change" do
      old_state = %{
        "progress_ms" => 90_000,
        "item" => %{"duration_ms" => 180_000},
        "device" => %{"id" => "device123"}
      }

      new_state = %{
        "progress_ms" => 85_000,
        "item" => %{"duration_ms" => 180_000},
        "device" => %{"id" => "device123"}
      }

      assert {:ok, ^new_state, []} = SpotifyPlayer.handle(old_state, new_state)
    end
  end

  describe "init" do
    test "fails to start when get_playback_state returns error during init", %{user: user} do
      Process.flag(:trap_exit, true)

      expect(SpotifyApi, :get_playback_state, fn _scope, %{} -> {:error, "Spotify API unavailable"} end)

      assert {:error, {:error, "Spotify API unavailable"}} = SpotifyPlayer.start_link(user.id)
    end

    test "publishes error event when init fails", %{user: user} do
      Process.flag(:trap_exit, true)

      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "playback:#{user.id}")

      expect(SpotifyApi, :get_playback_state, fn _scope, %{} -> {:error, "Spotify API unavailable"} end)

      assert {:error, {:error, "Spotify API unavailable"}} = SpotifyPlayer.start_link(user.id)

      assert_receive {:player, {:error, "Spotify API unavailable"}, %{}}
    end
  end

  describe "integration tests" do
    test "full polling cycle with state changes", %{user: user} do
      playback1 = %{
        "is_playing" => true,
        "device" => %{"id" => "device123"},
        "item" => %{"uri" => "spotify:track:123", "duration_ms" => 180_000},
        "progress_ms" => 0
      }

      playback2 = %{
        "is_playing" => true,
        "device" => %{"id" => "device123"},
        "item" => %{"uri" => "spotify:track:123", "duration_ms" => 180_000},
        "progress_ms" => 2000
      }

      expect(SpotifyApi, :get_playback_state, fn _scope, %{} -> {:ok, playback1} end)
      expect(SpotifyApi, :get_playback_state, fn _scope, _old_state -> {:ok, playback2} end)

      {:ok, pid} = SpotifyPlayer.start_link(user.id)

      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "playback:#{user.id}")

      test_pid = self()

      spawn(fn ->
        {:ok, _ref} = Presence.join(user.id)
        send(test_pid, :presence_joined)
        Process.sleep(:infinity)
      end)

      assert_receive :presence_joined

      send(pid, :poll)

      assert_receive {:player, :start_track, _state}

      GenServer.stop(pid)
    end

    test "starting player twice returns same GenServer", %{user: user} do
      playback = %{
        "is_playing" => true,
        "device" => %{"id" => "device123"},
        "item" => %{"uri" => "spotify:track:123", "duration_ms" => 180_000},
        "progress_ms" => 0
      }

      expect(SpotifyApi, :get_playback_state, fn _scope, %{} -> {:ok, playback} end)

      {:ok, pid1} = SpotifyPlayer.start_link(user.id)

      result = SpotifyPlayer.start_link(user.id)

      assert {:error, {:already_started, pid2}} = result

      assert pid1 == pid2

      GenServer.stop(pid1)
    end

    test "publishes :failed event when player stops due to error", %{user: user} do
      Process.flag(:trap_exit, true)

      playback = %{
        "is_playing" => true,
        "device" => %{"id" => "device123"},
        "item" => %{"uri" => "spotify:track:123", "duration_ms" => 180_000},
        "progress_ms" => 0
      }

      expect(SpotifyApi, :get_playback_state, fn _scope, %{} -> {:ok, playback} end)
      expect(SpotifyApi, :get_playback_state, fn _scope, _old_state -> {:error, "Spotify rate limit exceeded"} end)

      {:ok, pid} = SpotifyPlayer.start_link(user.id)

      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "playback:#{user.id}")

      test_pid = self()

      spawn(fn ->
        {:ok, _ref} = Presence.join(user.id)
        send(test_pid, :presence_joined)
        Process.sleep(:infinity)
      end)

      assert_receive :presence_joined

      send(pid, :poll)

      assert_receive {:player, {:error, "Spotify rate limit exceeded"}, _state}
      assert_receive {:EXIT, ^pid, {:error, "Spotify rate limit exceeded"}}
    end
  end
end
