defmodule PremiereEcouteWeb.Player.Channel do
  @moduledoc """
  Channel of the desktop player.

  Topic `desktop:<user_id>`, or `desktop:me` for a player that does not know its user id.

  Thin transport between the player and the user's `SpotifyPlayer`: validates incoming messages, forwards them and pushes commands. Also tells the player whether the streamer has a listening session (the `session` event, with no votes). Takes no decision.
  """

  use Phoenix.Channel

  require Logger

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.Players.Protocol
  alias PremiereEcoute.Apis.PlayerSupervisor
  alias PremiereEcoute.Devices
  alias PremiereEcoute.Sessions.ListeningSession

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
        refuse(user_id, "forbidden")

      payload["proto"] != @protocol ->
        refuse(user_id, "unsupported_protocol")

      true ->
        PremiereEcoute.PubSub.subscribe("player:revoked:#{user_id}")
        PremiereEcoute.PubSub.subscribe("playback:#{user_id}")
        send(self(), :push_session)
        Process.send_after(self(), :recheck, @recheck_ms)
        socket = assign(socket, :invalid, [])
        PlayerSupervisor.start({user_id, device: true})
        forward(socket, {:device_attached, self(), %{session_id: payload["session_id"], app_version: payload["app_version"]}})

        Logger.info(
          "Desktop player joined user=#{user_id} session=#{clean(payload["session_id"])} version=#{clean(payload["app_version"])}"
        )

        {:ok, %{"snapshot_interval_ms" => @snapshot_interval_ms}, socket}
    end
  end

  @impl true
  def handle_in("snapshot", payload, socket) do
    with {:ok, rate, socket} <- rate(socket),
         {:ok, seq, snapshot} <- Protocol.snapshot(payload) do
      # The reply says the server heard it: the player shows it. One dropped for arriving too fast
      # was not heard.
      if rate <= @snapshot_rate do
        forward(socket, {:device_snapshot, seq, snapshot})
        {:reply, :ok, socket}
      else
        {:noreply, socket}
      end
    else
      {:error, :invalid} -> invalid(socket, "snapshot")
      {:error, :flood} -> {:stop, {:shutdown, :flood}, socket}
    end
  end

  def handle_in("ack", payload, socket) do
    case Protocol.ack(payload) do
      {:ok, id, status, error} ->
        forward(socket, {:device_ack, id, status, error})
        {:noreply, socket}

      {:error, :invalid} ->
        invalid(socket, "ack")
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

  # The streamer's session changed, or its track did: tell the player, once per change.
  def handle_info(:push_session, %{assigns: %{user_id: user_id}} = socket) do
    session = ListeningSession.current(%User{id: user_id})
    socket = follow_session(socket, session)
    payload = session |> ListeningSession.summary() |> Protocol.session()

    if socket.assigns[:session] == payload do
      {:noreply, socket}
    else
      push(socket, "session", payload)
      {:noreply, assign(socket, :session, payload)}
    end
  end

  # What the session itself says: a track started, forwards or back, or it stopped.
  def handle_info({event, _track}, socket) when event in [:next_track, :previous_track, :track_captured],
    do: handle_info(:push_session, socket)

  def handle_info(:stop, socket), do: handle_info(:push_session, socket)

  def handle_info({event, _session_id}, socket) when event in [:session_prepared, :session_started, :session_stopped],
    do: handle_info(:push_session, socket)

  # A track starts from a pause at the end of the previous one (that is how a session plays), so
  # it is a `:start`, not a `:new_track`: both mean the position may have changed.
  def handle_info({:player, event, _state}, socket) when event in [:new_track, :start],
    do: handle_info(:push_session, socket)

  def handle_info(:player_revoked, socket), do: handle_info({:disconnect, :revoked}, socket)

  def handle_info({:disconnect, reason}, socket) do
    push(socket, "disconnect", Protocol.disconnect(reason))
    {:stop, {:shutdown, reason}, socket}
  end

  # The playback topic carries much more than sessions.
  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def terminate(reason, %{assigns: %{user_id: user_id}}) do
    Logger.info("Desktop player left user=#{user_id} reason=#{inspect(reason)}")
  end

  defp refuse(user_id, reason) do
    Logger.warning("Desktop player join refused user=#{user_id} reason=#{reason}")
    {:error, %{reason: reason}}
  end

  # Listens to the topic of the streamer's current session, and to no other: its track changes are
  # told there, before the player has even started the track.
  defp follow_session(%{assigns: assigns} = socket, session) do
    wanted = session && session.id

    if Map.get(assigns, :session_id) == wanted do
      socket
    else
      if old = Map.get(assigns, :session_id), do: PremiereEcoute.PubSub.unsubscribe("session:#{old}")
      if wanted, do: PremiereEcoute.PubSub.subscribe("session:#{wanted}")
      assign(socket, :session_id, wanted)
    end
  end

  # Values sent by the player are logged on one line, without control characters.
  defp clean(value) when is_binary(value), do: value |> String.replace(~r/[^\w.\-]/u, "_") |> String.slice(0, 64)
  defp clean(_value), do: "unknown"

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

  defp invalid(%{assigns: %{invalid: invalid, user_id: user_id}} = socket, event) do
    now = System.monotonic_time(:millisecond)
    invalid = [now | Enum.filter(invalid, &(now - &1 < @invalid_window_ms))]

    Logger.warning("Desktop player invalid #{event} user=#{user_id} recent=#{length(invalid)}")

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
