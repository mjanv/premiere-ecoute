defmodule PremiereEcouteWeb.Player.ChannelTest do
  use PremiereEcouteWeb.ChannelCase

  import ExUnit.CaptureLog

  import PremiereEcoute.PlayerFixtures

  alias PremiereEcoute.Apis.Players.PlayerRegistry
  alias PremiereEcoute.Apis.PlayerSupervisor
  alias PremiereEcoute.Devices
  alias PremiereEcouteWeb.Player.Channel
  alias PremiereEcouteWeb.Player.Socket

  @join %{"proto" => 1, "app_version" => "0.1.0", "session_id" => "7d1f6f0c-2c3b-4b53-a4ad-3a8d1a4f9c11"}

  setup do
    start_supervised({Registry, keys: :unique, name: PlayerRegistry})
    start_supervised({DynamicSupervisor, name: PlayerSupervisor, strategy: :one_for_one})

    user = user_fixture()
    %{access_token: token} = player_tokens(user)
    {:ok, socket} = connect(Socket, %{}, connect_info: %{x_headers: [{"x-access-token", token}]})

    %{user: user, socket: socket}
  end

  describe "join" do
    test "accepts the player's own topic and tells the snapshot interval", %{user: user, socket: socket} do
      assert {:ok, %{"snapshot_interval_ms" => 1_000}, _socket} =
               subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
    end

    test "starts the user's player and attaches to it", %{user: user, socket: socket} do
      Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "playback:#{user.id}")

      {:ok, _, socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)

      assert [{player, _}] = Registry.lookup(PlayerRegistry, user.id)
      assert_receive {:player, {:mode, :local}, _state}
      assert is_pid(player) and player != socket.channel_pid
    end

    test "accepts the me topic, as the player does not know its user id", %{socket: socket} do
      assert {:ok, %{"snapshot_interval_ms" => 1_000}, _socket} = subscribe_and_join(socket, Channel, "desktop:me", @join)
    end

    test "refuses another user's topic", %{user: user, socket: socket} do
      assert {:error, %{reason: "forbidden"}} =
               subscribe_and_join(socket, Channel, "desktop:#{user.id + 1}", @join)
    end

    test "refuses an unsupported protocol version", %{user: user, socket: socket} do
      assert {:error, %{reason: "unsupported_protocol"}} =
               subscribe_and_join(socket, Channel, "desktop:#{user.id}", %{@join | "proto" => 2})

      assert {:error, %{reason: "unsupported_protocol"}} =
               subscribe_and_join(socket, Channel, "desktop:#{user.id}", %{})
    end
  end

  describe "messages" do
    setup %{user: user, socket: socket} do
      {:ok, _} = Registry.register(PlayerRegistry, user.id, nil)
      {:ok, _, socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
      %{socket: socket}
    end

    test "forwards a valid snapshot to the user's player", %{socket: socket} do
      push(socket, "snapshot", %{"seq" => 1, "snapshot" => snapshot()})

      assert_receive {:device_snapshot, 1, forwarded}
      assert forwarded.playback == :playing
      assert forwarded.uri == "spotify:track:6rqhFgbbKwnb9MLmUQDhG6"
      assert forwarded.position_ms == 12_345
    end

    test "drops snapshots beyond five per second", %{socket: socket} do
      for seq <- 1..8, do: push(socket, "snapshot", %{"seq" => seq, "snapshot" => snapshot()})

      for seq <- 1..5, do: assert_receive({:device_snapshot, ^seq, _})
      refute_receive {:device_snapshot, _, _}
    end

    test "disconnects a player that sends more than twenty snapshots per second", %{socket: socket} do
      Process.flag(:trap_exit, true)
      ref = Process.monitor(socket.channel_pid)

      for seq <- 1..25, do: push(socket, "snapshot", %{"seq" => seq, "snapshot" => snapshot()})

      assert_receive {:DOWN, ^ref, :process, _pid, _reason}
    end

    test "does not forward an invalid snapshot", %{socket: socket} do
      push(socket, "snapshot", %{"seq" => 1, "snapshot" => snapshot(%{"playback" => "rewinding"})})
      push(socket, "snapshot", %{"seq" => 2, "snapshot" => snapshot(%{"volume" => 7})})
      push(socket, "snapshot", %{"seq" => "3"})

      refute_receive {:device_snapshot, _, _}
    end

    test "truncates long strings", %{socket: socket} do
      push(socket, "snapshot", %{"seq" => 1, "snapshot" => snapshot(%{"title" => String.duplicate("a", 600)})})

      assert_receive {:device_snapshot, 1, %{title: title}}
      assert String.length(title) == 512
    end

    test "disconnects a player that sends ten invalid payloads", %{socket: socket} do
      Process.flag(:trap_exit, true)
      ref = Process.monitor(socket.channel_pid)

      for seq <- 1..10, do: push(socket, "snapshot", %{"seq" => seq, "snapshot" => %{}})

      assert_receive {:DOWN, ^ref, :process, _pid, _reason}
    end

    test "forwards the ack of a command to the user's player", %{socket: socket} do
      push(socket, "ack", %{"command_id" => "c1", "status" => "ok"})
      push(socket, "ack", %{"command_id" => "c2", "status" => "rejected", "error" => "bad uri"})
      push(socket, "ack", %{"command_id" => "c3", "status" => "exploded"})

      assert_receive {:device_ack, "c1", :ok, nil}
      assert_receive {:device_ack, "c2", :rejected, "bad uri"}
      refute_receive {:device_ack, "c3", _, _}
    end

    test "pushes a command sent by the user's player", %{socket: socket} do
      send(socket.channel_pid, {:command, %{id: "c1", type: :set_volume, args: %{volume: 0.3}, ttl_ms: 10_000}})

      assert_push "command", %{"id" => "c1", "type" => "set_volume", "args" => %{"volume" => 0.3}, "ttl_ms" => 10_000}
    end

    test "tells the player it was revoked and stops when the user revokes the player", %{user: user, socket: socket} do
      Process.flag(:trap_exit, true)
      ref = Process.monitor(socket.channel_pid)

      :ok = Devices.revoke_player(user)

      assert_push "disconnect", %{"reason" => "revoked"}
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}
    end

    test "periodically checks that the player is still enrolled", %{socket: socket} do
      Process.flag(:trap_exit, true)
      ref = Process.monitor(socket.channel_pid)

      send(socket.channel_pid, :recheck)
      refute_receive {:DOWN, ^ref, :process, _pid, _reason}

      PremiereEcoute.Repo.update_all(Boruta.Ecto.Token, set: [refresh_token_revoked_at: DateTime.utc_now()])
      send(socket.channel_pid, :recheck)

      assert_push "disconnect", %{"reason" => "revoked"}
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}
    end

    test "pushes a disconnect reason and stops", %{socket: socket} do
      Process.flag(:trap_exit, true)
      ref = Process.monitor(socket.channel_pid)
      send(socket.channel_pid, {:disconnect, :replaced})

      assert_push "disconnect", %{"reason" => "replaced"}
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}
    end
  end

  describe "logs" do
    setup do
      previous = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: previous) end)
    end

    test "follow a player joining and leaving", %{user: user, socket: socket} do
      Process.flag(:trap_exit, true)

      log =
        capture_log(fn ->
          {:ok, _, socket} = subscribe_and_join(socket, Channel, "desktop:me", @join)
          ref = Process.monitor(socket.channel_pid)
          send(socket.channel_pid, {:disconnect, :replaced})
          assert_receive {:DOWN, ^ref, :process, _pid, _reason}
        end)

      assert log =~ "Desktop player joined user=#{user.id} session=7d1f6f0c-2c3b-4b53-a4ad-3a8d1a4f9c11 version=0.1.0"
      assert log =~ "Desktop player left user=#{user.id}"
      assert log =~ "replaced"
    end

    test "report a refused join", %{user: user, socket: socket} do
      log =
        capture_log(fn ->
          {:error, _} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", %{@join | "proto" => 2})
        end)

      assert log =~ "Desktop player join refused user=#{user.id} reason=unsupported_protocol"
    end

    test "report invalid payloads without their content", %{user: user, socket: socket} do
      {:ok, _, socket} = subscribe_and_join(socket, Channel, "desktop:me", @join)

      log =
        capture_log(fn ->
          push(socket, "snapshot", %{"seq" => 1, "snapshot" => %{"title" => "secret title"}})
          :sys.get_state(socket.channel_pid)
        end)

      assert log =~ "Desktop player invalid snapshot user=#{user.id}"
      refute log =~ "secret title"
    end
  end

  describe "attach" do
    test "tells the user's player that a device joined", %{user: user, socket: socket} do
      {:ok, _} = Registry.register(PlayerRegistry, user.id, nil)

      {:ok, _, socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)

      channel_pid = socket.channel_pid
      assert_receive {:device_attached, ^channel_pid, %{session_id: "7d1f6f0c-2c3b-4b53-a4ad-3a8d1a4f9c11"}}
    end
  end

  defp snapshot(overrides \\ %{}) do
    Map.merge(
      %{
        "running" => true,
        "playback" => "playing",
        "uri" => "spotify:track:6rqhFgbbKwnb9MLmUQDhG6",
        "title" => "Song",
        "artist" => "Artist",
        "album" => "Album",
        "position_ms" => 12_345,
        "length_ms" => 215_000,
        "volume" => 0.5
      },
      overrides
    )
  end
end
