defmodule PremiereEcouteWeb.Player.LongSessionTest do
  @moduledoc """
  A listening session can last more than the hour an access token lives: an album is longer.
  """

  use PremiereEcouteWeb.ChannelCase

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
    %{user: user_fixture()}
  end

  defp connect_with(token), do: connect(Socket, %{}, connect_info: %{x_headers: [{"x-access-token", token}]})

  defp snapshot, do: %{"running" => true, "playback" => "playing", "position_ms" => 1, "length_ms" => 100_000, "volume" => 0.5}

  describe "a player that stays connected while its access token expires" do
    setup %{user: user} do
      %{access_token: access, refresh_token: refresh} = player_tokens(user)
      {:ok, socket} = connect_with(access)
      {:ok, _, socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
      %{socket: socket, access: access, refresh: refresh}
    end

    test "is not disconnected by the periodic check", %{socket: socket, access: access, user: user} do
      expire_access_token(access)

      send(socket.channel_pid, :recheck)

      refute_push "disconnect", _
      assert Process.alive?(socket.channel_pid)
      assert Devices.player_enrolled?(user)
    end

    test "keeps being heard, and acknowledged, after the token expired", %{socket: socket, access: access} do
      expire_access_token(access)

      ref = push(socket, "snapshot", %{"seq" => 1, "snapshot" => snapshot()})

      assert_reply ref, :ok
    end

    test "still gets its commands and the session", %{socket: socket, access: access} do
      expire_access_token(access)

      send(socket.channel_pid, {:command, %{id: "c1", type: :next, args: %{}, ttl_ms: 10_000}})

      assert_push "command", %{"id" => "c1", "type" => "next"}
    end
  end

  describe "a player that reconnects after its access token expired" do
    test "is refused with the expired token", %{user: user} do
      %{access_token: access} = player_tokens(user)
      expire_access_token(access)

      assert connect_with(access) == :error
    end

    test "is let in again with a refreshed token, and is still enrolled", %{user: user} do
      %{access_token: access, refresh_token: refresh} = player_tokens(user)
      expire_access_token(access)

      assert {:ok, %{access_token: fresh, refresh_token: rotated}} = refresh_player_tokens(refresh)

      assert {:ok, socket} = connect_with(fresh)
      assert socket.assigns.user_id == user.id
      assert rotated != refresh
      assert Devices.player_enrolled?(user)
    end

    test "cannot use the refresh token it already used", %{user: user} do
      %{refresh_token: refresh} = player_tokens(user)
      {:ok, _} = refresh_player_tokens(refresh)

      assert {:error, _} = refresh_player_tokens(refresh)
    end

    test "stays enrolled through many hours of refreshes", %{user: user} do
      %{access_token: first, refresh_token: first_refresh} = player_tokens(user)

      {last_access, _} =
        Enum.reduce(1..12, {first, first_refresh}, fn _hour, {access, refresh} ->
          expire_access_token(access)
          assert {:ok, %{access_token: next, refresh_token: next_refresh}} = refresh_player_tokens(refresh)
          assert Devices.player_enrolled?(user)
          {next, next_refresh}
        end)

      assert {:ok, _socket} = connect_with(last_access)
    end

    test "a revoked player is still sent away, expired token or not", %{user: user} do
      %{access_token: access} = player_tokens(user)
      {:ok, socket} = connect_with(access)
      {:ok, _, socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
      expire_access_token(access)

      Process.flag(:trap_exit, true)
      ref = Process.monitor(socket.channel_pid)
      :ok = Devices.revoke_player(user)

      assert_push "disconnect", %{"reason" => "revoked"}
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}
    end
  end
end
