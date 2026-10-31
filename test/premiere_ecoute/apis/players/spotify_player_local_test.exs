defmodule PremiereEcoute.Apis.Players.SpotifyPlayerLocalTest do
  use PremiereEcoute.DataCase

  import ExUnit.CaptureLog

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.NotConnectedError
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Apis.Players.SpotifyPlayer

  @uri "spotify:track:6rqhFgbbKwnb9MLmUQDhG6"

  setup do
    user = user_fixture()
    Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "playback:#{user.id}")

    data = %{
      scope: user_scope_fixture(user),
      phx_ref: nil,
      polls: 100,
      failures: 0,
      state: PlaybackState.default()
    }

    {:ok, %{user: user, data: data}}
  end

  describe "local mode: snapshots" do
    setup %{data: data} do
      device = spawn(fn -> Process.sleep(:infinity) end)
      {:noreply, data} = SpotifyPlayer.handle_info({:device_attached, device, %{session_id: "s1"}}, data)
      {:ok, %{data: data, device: device}}
    end

    test "turns a snapshot into the playback state", %{data: data} do
      assert {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot()}, data)

      assert %PlaybackState{is_playing: true, progress_ms: 12_345, device: %{is_active: true}} = data.state
      assert %{uri: @uri, name: "Song", duration_ms: 215_000, artists: [%{name: "Artist"}]} = data.state.item
      assert data.state.item.album.name == "Album"
    end

    test "publishes the events between two snapshots", %{data: data} do
      {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot()}, data)
      {:noreply, _data} = SpotifyPlayer.handle_info({:device_snapshot, 2, snapshot(%{playback: :paused})}, data)

      assert_receive {:player, :stop, %PlaybackState{is_playing: false}}
    end

    test "reports no device when the desktop Spotify is not running", %{data: data} do
      {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot()}, data)

      {:noreply, data} =
        SpotifyPlayer.handle_info({:device_snapshot, 2, snapshot(%{running: false, playback: :stopped, uri: nil})}, data)

      assert data.state.device == nil
      assert_receive {:player, :no_device, _state}
    end

    test "ignores a snapshot that is not newer than the last one", %{data: data} do
      {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 5, snapshot()}, data)

      assert {:noreply, ^data} = SpotifyPlayer.handle_info({:device_snapshot, 5, snapshot(%{playback: :paused})}, data)
      assert {:noreply, ^data} = SpotifyPlayer.handle_info({:device_snapshot, 3, snapshot(%{playback: :paused})}, data)
    end
  end

  describe "switching to local mode" do
    test "stops polling the Web API and starts from a blank playback state", %{data: data} do
      data = Map.merge(data, %{state: playing_state(), poll_timer: Process.send_after(self(), :poll, 50)})
      device = spawn(fn -> Process.sleep(:infinity) end)

      assert {:noreply, data} = SpotifyPlayer.handle_info({:device_attached, device, %{session_id: "s1"}}, data)

      assert data.mode == :local
      assert data.state == PlaybackState.default()
      assert data.device.pid == device
      assert data.device.session_id == "s1"
      refute_receive :poll, 100
      assert_receive {:player, {:mode, :local}, _state}
    end

    test "tells the previous device it was replaced", %{data: data} do
      first = self()
      second = spawn(fn -> Process.sleep(:infinity) end)

      {:noreply, data} = SpotifyPlayer.handle_info({:device_attached, first, %{}}, data)
      {:noreply, data} = SpotifyPlayer.handle_info({:device_attached, second, %{}}, data)

      assert_receive {:disconnect, :replaced}
      assert data.device.pid == second
    end

    test "ignores Web API polling and overlay shutdown while a device is attached", %{data: data} do
      device = spawn(fn -> Process.sleep(:infinity) end)
      {:noreply, data} = SpotifyPlayer.handle_info({:device_attached, device, %{}}, %{data | polls: 0})

      assert {:noreply, ^data} = SpotifyPlayer.handle_info(:poll, data)
      assert {:noreply, ^data} = SpotifyPlayer.handle_info(:no_overlay, data)
    end
  end

  describe "switching back to api mode" do
    setup %{data: data} do
      device = spawn(fn -> Process.sleep(:infinity) end)
      {:noreply, data} = SpotifyPlayer.handle_info({:device_attached, device, %{}}, %{data | polls: 3, failures: 4})
      {:ok, %{data: data, device: device}}
    end

    test "when the device disconnects", %{data: data, device: device} do
      ref = data.device.ref

      assert {:noreply, data} = SpotifyPlayer.handle_info({:DOWN, ref, :process, device, :normal}, data)

      assert data.mode == :api
      assert data.state == PlaybackState.default()
      assert data.polls > 3
      assert data.failures == 0
      refute Map.has_key?(data, :device)
      assert_receive :poll
      assert_receive {:player, {:mode, :api}, _state}
    end

    test "when the device goes silent", %{data: data} do
      silent = %{data | last_seen_ms: System.monotonic_time(:millisecond) - 6_000}

      assert {:noreply, data} = SpotifyPlayer.handle_info(:stale_check, silent)

      assert data.mode == :api
    end

    test "not while snapshots keep coming", %{data: data} do
      assert {:noreply, data} = SpotifyPlayer.handle_info(:stale_check, data)

      assert data.mode == :local
      assert is_reference(data.stale_timer)
    end

    test "not for an unrelated process going down", %{data: data} do
      assert {:noreply, ^data} = SpotifyPlayer.handle_info({:DOWN, make_ref(), :process, self(), :normal}, data)
    end
  end

  describe "user without a linked Spotify account" do
    test "stops polling the Web API without counting a failure and waits for a device", %{data: data} do
      expect(SpotifyApi, :get_playback_state, fn _scope, _state -> raise NotConnectedError end)

      assert {:noreply, data} = SpotifyPlayer.handle_info(:poll, data)

      assert data.failures == 0
      assert is_reference(data.idle_timer)
      refute_receive :poll, 100
    end

    test "stops after the idle timeout", %{data: data} do
      assert {:stop, :normal, ^data} = SpotifyPlayer.handle_info(:idle_timeout, data)
    end

    test "does not stop once a device is attached", %{data: data} do
      data = Map.put(data, :idle_timer, Process.send_after(self(), :idle_timeout, 50))
      device = spawn(fn -> Process.sleep(:infinity) end)

      {:noreply, data} = SpotifyPlayer.handle_info({:device_attached, device, %{}}, data)

      refute_receive :idle_timeout, 100
      assert {:noreply, ^data} = SpotifyPlayer.handle_info(:idle_timeout, data)
    end

    test "starts even though the Web API cannot be used", %{user: user} do
      start_supervised({Registry, keys: :unique, name: PremiereEcoute.Apis.Players.PlayerRegistry})
      expect(SpotifyApi, :get_playback_state, fn _scope, _state -> raise NotConnectedError end)

      assert {:ok, pid} = SpotifyPlayer.start_link(user.id)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end

  describe "started for a desktop player" do
    setup do
      start_supervised({Registry, keys: :unique, name: PremiereEcoute.Apis.Players.PlayerRegistry})
      :ok
    end

    test "does not call the Web API and waits for the device", %{user: user} do
      assert {:ok, player} = SpotifyPlayer.start_link({user.id, device: true})

      assert [{^player, _}] = Registry.lookup(PremiereEcoute.Apis.Players.PlayerRegistry, user.id)
      assert is_reference(:sys.get_state(player).idle_timer)

      GenServer.stop(player)
    end

    test "follows the device once attached", %{user: user} do
      {:ok, player} = SpotifyPlayer.start_link({user.id, device: true})
      device = spawn(fn -> Process.sleep(:infinity) end)

      send(player, {:device_attached, device, %{}})
      state = :sys.get_state(player)

      assert state.mode == :local
      refute Map.has_key?(state, :idle_timer)

      GenServer.stop(player)
    end
  end

  describe "local mode: logs" do
    setup %{data: data} do
      previous = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: previous) end)

      device = spawn(fn -> Process.sleep(:infinity) end)
      {:noreply, data} = SpotifyPlayer.handle_info({:device_attached, device, %{}}, data)
      {:ok, %{data: data}}
    end

    test "state changes are logged with what the player sent", %{user: user, data: data} do
      log = capture_log(fn -> SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot()}, data) end)

      assert log =~
               ~s(Desktop player state user=#{user.id} running=true playback=playing uri="#{@uri}" title="Song" artist="Artist" album="Album")
    end

    test "an unchanged state is not logged again", %{data: data} do
      {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot()}, data)

      log = capture_log(fn -> SpotifyPlayer.handle_info({:device_snapshot, 2, snapshot(%{position_ms: 13_345})}, data) end)

      refute log =~ "Desktop player state"
    end

    test "a pause or a new track is logged", %{data: data} do
      {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot()}, data)

      log = capture_log(fn -> SpotifyPlayer.handle_info({:device_snapshot, 2, snapshot(%{playback: :paused})}, data) end)
      assert log =~ "playback=paused"

      log =
        capture_log(fn ->
          SpotifyPlayer.handle_info({:device_snapshot, 2, snapshot(%{title: "Other", uri: "spotify:track:other"})}, data)
        end)

      assert log =~ ~s(title="Other")
    end

    test "text from the player cannot add log lines", %{data: data} do
      log = capture_log(fn -> SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot(%{title: "a\n[error] forged"})}, data) end)

      assert log =~ ~s(title="a\\n[error] forged")
    end

    test "every snapshot is logged at debug level", %{user: user, data: data} do
      Logger.configure(level: :debug)
      {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot()}, data)

      log = capture_log(fn -> SpotifyPlayer.handle_info({:device_snapshot, 2, snapshot(%{position_ms: 13_345})}, data) end)

      assert log =~ "Desktop player snapshot user=#{user.id} seq=2 position_ms=13345"
    end
  end

  defp playing_state do
    %PlaybackState{is_playing: true, progress_ms: 1, device: %{name: "phone", is_active: true}, item: nil}
  end

  defp snapshot(overrides \\ %{}) do
    Map.merge(
      %{
        running: true,
        playback: :playing,
        uri: @uri,
        title: "Song",
        artist: "Artist",
        album: "Album",
        position_ms: 12_345,
        length_ms: 215_000,
        volume: 0.5
      },
      overrides
    )
  end
end
