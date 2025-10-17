defmodule PremiereEcoute.Apis.SpotifyPlayerTest do
  use PremiereEcoute.DataCase

  import ExUnit.CaptureLog

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.SpotifyPlayer
  alias PremiereEcoute.Presence

  @moduletag :skip

  setup do
    user = user_fixture()
    scope = user_scope_fixture(user)

    registry_name = PremiereEcoute.Apis.PlayerRegistry

    # Start registry if not already started
    case Registry.start_link(keys: :unique, name: registry_name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    {:ok, %{user: user, scope: scope}}
  end

  describe "handle_info(:poll, state)" do
    setup %{user: user} do
      scope = user_scope_fixture(user)

      initial_state = %{
        scope: scope,
        phx_ref: "ref123",
        state: %{"is_playing" => false, "device" => %{"id" => "device123"}}
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

      expect(PremiereEcoute.Accounts, :maybe_renew_token, fn _conn, :spotify ->
        initial_state.scope
      end)

      expect(SpotifyApi, :get_playback_state, fn _scope, _old_state ->
        {:ok, new_playback_state}
      end)

      expect(Presence, :player, fn _user_id -> [self(), self()] end)

      # Mock PubSub broadcast
      test_pid = self()

      expect(PremiereEcoute.PubSub, :broadcast, fn topic, message ->
        send(test_pid, {:broadcast, topic, message})
        :ok
      end)

      assert {:noreply, new_state} = SpotifyPlayer.handle_info(:poll, initial_state)

      assert new_state.state == new_playback_state
      assert_received {:broadcast, _topic, {:player, :start, _state}}
    end

    test "stops when only one presence left", %{initial_state: initial_state} do
      expect(PremiereEcoute.Accounts, :maybe_renew_token, fn _conn, :spotify ->
        initial_state.scope
      end)

      expect(SpotifyApi, :get_playback_state, fn _scope, _old_state ->
        {:ok, %{"is_playing" => false}}
      end)

      expect(Presence, :player, fn _user_id -> [self()] end)

      assert {:stop, :normal, _state} = SpotifyPlayer.handle_info(:poll, initial_state)
    end
  end

  describe "terminate/2" do
    test "logs termination reason" do
      assert capture_log(fn ->
               SpotifyPlayer.terminate(:normal, %{})
             end) =~ "Stop Spotify player due to: :normal"
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

      # Should not crash and return a reasonable value
      assert is_integer(SpotifyPlayer.progress(state))
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
        "progress_ms" => 1_800,
        "item" => %{"duration_ms" => 180_000},
        "device" => %{"id" => "device123"}
      }

      assert {:ok, ^new_state, [:start_track]} = SpotifyPlayer.handle(old_state, new_state)
    end

    test "detects track end (97% to 98% progress)" do
      old_state = %{
        "progress_ms" => 174_600,
        "item" => %{"duration_ms" => 180_000},
        "device" => %{"id" => "device123"}
      }

      new_state = %{
        "progress_ms" => 176_400,
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

      assert {:ok, ^new_state, [{:skip, 50}]} = SpotifyPlayer.handle(old_state, new_state)
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

      assert {:ok, ^new_state, [{:percent, 15}]} = SpotifyPlayer.handle(old_state, new_state)
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

  describe "integration tests" do
    test "full polling cycle with state changes", %{user: user} do
      initial_playback = %{
        "is_playing" => false,
        "device" => %{"id" => "device123"},
        "item" => %{"uri" => "spotify:track:123", "duration_ms" => 180_000},
        "progress_ms" => 0
      }

      updated_playback = %{
        "is_playing" => true,
        "device" => %{"id" => "device123"},
        "item" => %{"uri" => "spotify:track:123", "duration_ms" => 180_000},
        "progress_ms" => 1800
      }

      expect(SpotifyApi, :get_playback_state, fn _scope, %{} ->
        {:ok, initial_playback}
      end)

      expect(Presence, :join, fn _user_id -> {:ok, "ref123"} end)

      {:ok, pid} = SpotifyPlayer.start_link(user.id)

      # Mock subsequent polling calls
      expect(PremiereEcoute.Accounts, :maybe_renew_token, fn _conn, :spotify ->
        user_scope_fixture(user)
      end)

      expect(SpotifyApi, :get_playback_state, fn _scope, _old_state ->
        {:ok, updated_playback}
      end)

      expect(Presence, :player, fn _user_id -> [self(), self()] end)

      test_pid = self()

      expect(PremiereEcoute.PubSub, :broadcast, fn topic, message ->
        send(test_pid, {:broadcast, topic, message})
        :ok
      end)

      # Trigger polling
      send(pid, :poll)

      # Verify events were published
      assert_receive {:broadcast, _topic, {:player, :start, _state}}
      assert_receive {:broadcast, _topic, {:player, :start_track, _state}}

      GenServer.stop(pid)
    end
  end
end
