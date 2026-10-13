defmodule PremiereEcouteWeb.Player.Channel do
  @moduledoc """
  Channel of the desktop player.

  Topic `desktop:<user_id>`, or `desktop:me` for a player that does not know its user id.

  Thin transport between the player and the user's `SpotifyPlayer`: validates incoming messages, forwards them and pushes commands. Takes no decision.
  """

  use Phoenix.Channel

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.PlayerSupervisor
  alias PremiereEcoute.Devices
  alias PremiereEcouteWeb.Player.Protocol

  @registry PremiereEcoute.Apis.Players.PlayerRegistry

  @protocol 1
  @snapshot_interval_ms 1_000
  @recheck_ms 300_000
  @snapshot_rate 5
  @snapshot_flood 20
  @invalid_limit 10
  @invalid_window_ms 60_000

  @impl true
  def join("desktop:" <> topic_user_id, payload, %{assigns: %{user_id: user_id}} = socket) do
    cond do
      topic_user_id not in ["me", to_string(user_id)] ->
        {:error, %{reason: "forbidden"}}

      payload["proto"] != @protocol ->
        {:error, %{reason: "unsupported_protocol"}}

      true ->
        PremiereEcoute.PubSub.subscribe("player:revoked:#{user_id}")
        Process.send_after(self(), :recheck, @recheck_ms)
        socket = assign(socket, :invalid, [])
        PlayerSupervisor.start({user_id, device: true})
        forward(socket, {:device_attached, self(), %{session_id: payload["session_id"], app_version: payload["app_version"]}})
        {:ok, %{"snapshot_interval_ms" => @snapshot_interval_ms}, socket}
    end
  end

  @impl true
  def handle_in("snapshot", payload, socket) do
    with {:ok, rate, socket} <- rate(socket),
         {:ok, seq, snapshot} <- Protocol.snapshot(payload) do
      if rate <= @snapshot_rate, do: forward(socket, {:device_snapshot, seq, snapshot})
      {:noreply, socket}
    else
      {:error, :invalid} -> invalid(socket)
      {:error, :flood} -> {:stop, {:shutdown, :flood}, socket}
    end
  end

  def handle_in("ack", payload, socket) do
    case Protocol.ack(payload) do
      {:ok, id, status, error} ->
        forward(socket, {:device_ack, id, status, error})
        {:noreply, socket}

      {:error, :invalid} ->
        invalid(socket)
    end
  end

  def handle_in(_event, _payload, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:command, command}, socket) do
    push(socket, "command", Protocol.command(command))
    {:noreply, socket}
  end

  def handle_info(:recheck, %{assigns: %{user_id: user_id}} = socket) do
    if Devices.player_enrolled?(%User{id: user_id}) do
      Process.send_after(self(), :recheck, @recheck_ms)
      {:noreply, socket}
    else
      handle_info({:disconnect, :revoked}, socket)
    end
  end

  def handle_info(:player_revoked, socket), do: handle_info({:disconnect, :revoked}, socket)

  def handle_info({:disconnect, reason}, socket) do
    push(socket, "disconnect", Protocol.disconnect(reason))
    {:stop, {:shutdown, reason}, socket}
  end

  # Number of snapshots received during the last second, this one included.
  defp rate(%{assigns: assigns} = socket) do
    now = System.monotonic_time(:millisecond)
    received = [now | Enum.filter(Map.get(assigns, :received, []), &(now - &1 < 1_000))]

    if length(received) > @snapshot_flood do
      {:error, :flood}
    else
      {:ok, length(received), assign(socket, :received, received)}
    end
  end

  defp invalid(%{assigns: %{invalid: invalid}} = socket) do
    now = System.monotonic_time(:millisecond)
    invalid = [now | Enum.filter(invalid, &(now - &1 < @invalid_window_ms))]

    if length(invalid) >= @invalid_limit do
      {:stop, {:shutdown, :invalid_payloads}, socket}
    else
      {:noreply, assign(socket, :invalid, invalid)}
    end
  end

  defp forward(%{assigns: %{user_id: user_id}}, message) do
    for {pid, _} <- Registry.lookup(@registry, user_id), do: send(pid, message)
    :ok
  end
end
