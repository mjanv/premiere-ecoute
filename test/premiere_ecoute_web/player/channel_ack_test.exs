defmodule PremiereEcouteWeb.Player.ChannelAckTest do
  use PremiereEcouteWeb.ChannelCase

  import PremiereEcoute.PlayerFixtures

  alias PremiereEcoute.Apis.Players.PlayerRegistry
  alias PremiereEcoute.Apis.PlayerSupervisor
  alias PremiereEcouteWeb.Player.Channel
  alias PremiereEcouteWeb.Player.Socket

  @join %{"proto" => 1, "app_version" => "0.1.0", "session_id" => "7d1f6f0c-2c3b-4b53-a4ad-3a8d1a4f9c11"}

  setup do
    start_supervised({Registry, keys: :unique, name: PlayerRegistry})
    start_supervised({DynamicSupervisor, name: PlayerSupervisor, strategy: :one_for_one})

    user = user_fixture()
    %{access_token: token} = player_tokens(user)
    {:ok, socket} = connect(Socket, %{}, connect_info: %{x_headers: [{"x-access-token", token}]})
    {:ok, _, socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
    %{socket: socket}
  end

  defp snapshot(overrides \\ %{}) do
    Map.merge(
      %{"running" => true, "playback" => "playing", "position_ms" => 1, "length_ms" => 100_000, "volume" => 0.5},
      overrides
    )
  end

  test "a valid snapshot is acknowledged, so the player knows the server heard it", %{socket: socket} do
    ref = push(socket, "snapshot", %{"seq" => 1, "snapshot" => snapshot()})

    assert_reply ref, :ok
  end

  test "every snapshot gets its own acknowledgement", %{socket: socket} do
    refs = for seq <- 1..3, do: push(socket, "snapshot", %{"seq" => seq, "snapshot" => snapshot()})

    for ref <- refs, do: assert_reply(ref, :ok)
  end

  test "an invalid snapshot is not acknowledged: the server did not hear anything usable", %{socket: socket} do
    ref = push(socket, "snapshot", %{"seq" => 1, "snapshot" => snapshot(%{"playback" => "rewinding"})})

    refute_reply ref, :ok
  end

  test "a snapshot dropped for arriving too fast is not acknowledged", %{socket: socket} do
    refs = for seq <- 1..8, do: push(socket, "snapshot", %{"seq" => seq, "snapshot" => snapshot()})

    {heard, dropped} = Enum.split(refs, 5)
    for ref <- heard, do: assert_reply(ref, :ok)
    for ref <- dropped, do: refute_reply(ref, :ok)
  end
end
