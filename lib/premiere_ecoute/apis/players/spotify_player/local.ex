defmodule PremiereEcoute.Apis.Players.SpotifyPlayer.Local do
  @moduledoc """
  Local mode of the Spotify player.

  Follows the desktop player connected by the streamer: no polling, the playback state comes from the snapshots it pushes. Falls back to the Api mode when the device disconnects or goes silent.
  """

  @behaviour PremiereEcoute.Apis.Players.SpotifyPlayer.Mode

  require Logger

  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Apis.Players.Protocol
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Playlist
  alias PremiereEcoute.Discography.Playlist.Track, as: PlaylistTrack
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Discography.TrackMatch

  @stale_after_ms 5_000
  @stale_check_ms 1_000
  @command_ttl_ms 10_000
  @command_grace_ms 2_000
  @keys [:device, :last_seq, :last_seen_ms, :stale_timer, :pending, :resolved]

  @doc """
  Enters the local mode for the device connected through `pid`.

  Monitors the device and starts the staleness check. The playback state starts from the default one, it is not diffed against what the Web API reported.
  """
  @spec enter(map(), pid(), map()) :: map()
  def enter(data, pid, meta) do
    data
    |> Map.merge(%{
      mode: :local,
      state: PlaybackState.default(),
      device: %{pid: pid, ref: Process.monitor(pid), session_id: Map.get(meta, :session_id)},
      last_seq: -1,
      last_seen_ms: now(),
      pending: %{}
    })
    |> schedule_stale_check()
  end

  @doc """
  Leaves the local mode: stops monitoring the device and cancels the staleness check.
  """
  @spec leave(map()) :: map()
  def leave(%{device: %{ref: ref}} = data) do
    Process.demonitor(ref, [:flush])
    if timer = data[:stale_timer], do: Process.cancel_timer(timer)

    # A command already sent to the device may have been executed: its result is unknown.
    for {id, {from, timer, _result, type}} <- data.pending do
      Process.cancel_timer(timer)
      Logger.warning("Desktop player command without ack user=#{user(data)} id=#{id} type=#{type} reason=disconnected")
      GenServer.reply(from, {:error, :unknown})
    end

    Map.drop(data, @keys)
  end

  def leave(data), do: Map.drop(data, @keys)

  @impl true
  def handle_info({:device_snapshot, seq, snapshot}, %{last_seq: last_seq} = data) when seq > last_seq do
    {resolved, data} = resolve(snapshot, data)
    state = Protocol.playback_state(resolved)
    log_snapshot(data, seq, snapshot, state)
    {:observe, state, %{data | last_seq: seq, last_seen_ms: now()}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{device: %{ref: ref}} = data) do
    Logger.info("Desktop player lost user=#{user(data)} reason=disconnected, back to the Web API")
    {:switch, :api, data}
  end

  def handle_info(:stale_check, %{last_seen_ms: last_seen_ms} = data) do
    if now() - last_seen_ms > @stale_after_ms do
      Logger.info("Desktop player lost user=#{user(data)} reason=silent, back to the Web API")
      {:switch, :api, data}
    else
      {:noreply, schedule_stale_check(data)}
    end
  end

  def handle_info({:device_ack, id, status, _error}, data) do
    case Map.pop(data.pending, id) do
      {nil, _pending} ->
        {:noreply, data}

      {{from, timer, result, type}, pending} ->
        Process.cancel_timer(timer)
        Logger.info("Desktop player command acked user=#{user(data)} id=#{id} type=#{type} status=#{status}")
        reply = reply(status, result)
        if reply == :api, do: log_fallback(data, type, "status=#{status}")
        GenServer.reply(from, reply)
        {:noreply, %{data | pending: pending}}
    end
  end

  def handle_info({:command_expired, id}, data) do
    case Map.pop(data.pending, id) do
      {nil, _pending} ->
        {:noreply, data}

      {{from, _timer, _result, type}, pending} ->
        Logger.warning("Desktop player command without ack user=#{user(data)} id=#{id} type=#{type} reason=timeout")
        GenServer.reply(from, {:error, :unknown})
        {:noreply, %{data | pending: pending}}
    end
  end

  def handle_info(_message, data), do: {:noreply, data}

  # Windows does not tell which Spotify track plays, so the player sends a made-up `spotify:local:` uri (see `docs/guides/desktop-player.md`). Whatever needs a real `spotify:track:` uri (wantlist save, radio, single track sessions) gets it from the stored discography. The answer is kept for as long as the made-up uri does not change, so a track costs one lookup. An unknown song keeps its made-up uri: track changes are still seen.
  defp resolve(%{uri: "spotify:local:" <> _ = uri} = snapshot, data) do
    case data[:resolved] do
      {^uri, real} ->
        {use_resolved(snapshot, real), data}

      _ ->
        real = lookup(snapshot, data)
        {use_resolved(snapshot, real), Map.put(data, :resolved, {uri, real})}
    end
  end

  defp resolve(snapshot, data), do: {snapshot, data}

  defp use_resolved(snapshot, nil), do: snapshot
  defp use_resolved(snapshot, uri), do: %{snapshot | uri: uri}

  # A failing lookup must never stop the player from following the desktop app.
  defp lookup(snapshot, data) do
    wanted = %{
      title: snapshot.title,
      artist: snapshot.artist,
      album: snapshot.album,
      track_number: Map.get(snapshot, :track_number),
      length_ms: snapshot.length_ms
    }

    case TrackMatch.find(wanted) do
      {:ok, id} ->
        uri = "spotify:track:" <> id
        Logger.info("Desktop player track resolved user=#{user(data)} title=#{inspect(snapshot.title)} uri=#{uri}")
        uri

      :error ->
        Logger.info(
          "Desktop player track unknown user=#{user(data)} title=#{inspect(snapshot.title)} artist=#{inspect(snapshot.artist)}"
        )

        nil
    end
  rescue
    error ->
      Logger.warning("Desktop player track lookup failed user=#{user(data)} reason=#{Exception.message(error)}")
      nil
  end

  # `:rejected`, `:expired` and `:error` guarantee that the command was not executed: the Web API takes over.
  defp reply(:ok, result), do: result
  defp reply(status, _result) when status in [:rejected, :expired, :error], do: :api
  defp reply(_status, _result), do: {:error, :unknown}

  @impl true
  # A playlist as a context (what a playlist session asks for when it starts): the desktop player
  # plays one track at a time, and the session starts them one by one (the first on autostart, as
  # for an album), so there is nothing to play and nothing to ask the Web API.
  def command({:play, %Playlist{}}, _from, data) do
    Logger.info("Desktop player command skipped user=#{user(data)} command=play reason=playlist_context")
    {:reply, {:ok, :skipped}, data}
  end

  def command({:play, target}, from, data) do
    case track_uri(target) do
      nil ->
        log_fallback(data, :play, "reason=unsupported")
        {:reply, :api, data}

      uri ->
        push(data, from, :play_uri, play_args(uri, target), {:ok, uri})
    end
  end

  def command(:pause, from, %{state: %{is_playing: true}} = data), do: push(data, from, :toggle_play_pause, %{}, {:ok, :paused})
  def command(:pause, _from, data), do: {:reply, {:ok, :paused}, data}

  def command(:next, from, data), do: push(data, from, :next, %{}, {:ok, :next})
  def command(:previous, from, data), do: push(data, from, :previous, %{}, {:ok, :previous})

  def command({:set_volume, volume}, from, data) when is_number(volume) and volume >= 0 and volume <= 1,
    do: push(data, from, :set_volume, %{volume: volume}, {:ok, volume})

  def command({:set_volume, _volume}, _from, data), do: {:reply, {:error, :invalid_volume}, data}

  # Without a first snapshot the desktop player state is not known yet.
  def command(:active_device, _from, %{last_seq: -1} = data) do
    log_fallback(data, :active_device, "reason=no_snapshot_yet")
    {:reply, :api, data}
  end

  def command(:active_device, _from, %{state: %{device: nil}} = data), do: {:reply, {:error, :no_active_device}, data}
  def command(:active_device, _from, data), do: {:reply, {:ok, :active}, data}

  # The desktop player plays one track at a time, there is no shuffle nor repeat to reset.
  def command({:shuffle, _shuffle}, _from, data), do: {:reply, {:ok, :skipped}, data}
  def command({:repeat, _mode}, _from, data), do: {:reply, {:ok, :skipped}, data}

  def command(command, _from, data) do
    log_fallback(data, command_name(command), "reason=unsupported")
    {:reply, :api, data}
  end

  defp push(%{device: %{pid: pid}} = data, from, type, args, result) do
    id = UUID.uuid4()
    send(pid, {:command, %{id: id, type: type, args: args, ttl_ms: @command_ttl_ms}})
    Logger.info("Desktop player command sent user=#{user(data)} id=#{id} type=#{type}")
    timer = Process.send_after(self(), {:command_expired, id}, @command_ttl_ms + @command_grace_ms)
    {:noreply, %{data | pending: Map.put(data.pending, id, {from, timer, result, type})}}
  end

  # The desktop app does not always start the track it is asked for (asked for the first track of an
  # album, it may go back to where the album was left): the position of an album track in its album
  # lets the player check what plays, and navigate to the right track. The exact length lets it
  # pause close to the end: the length the media session reports is rounded up by up to a second.
  defp play_args(uri, target) do
    %{uri: uri}
    |> put_positive(:track_number, track_number(target))
    |> put_positive(:duration_ms, duration_ms(target))
  end

  defp put_positive(args, key, value) when is_integer(value) and value > 0, do: Map.put(args, key, value)
  defp put_positive(args, _key, _value), do: args

  defp track_number(%Track{track_number: number}), do: number
  defp track_number(_target), do: nil

  defp duration_ms(%Track{duration_ms: duration}), do: duration
  defp duration_ms(%Single{duration_ms: duration}), do: duration
  defp duration_ms(%PlaylistTrack{duration_ms: duration}), do: duration
  defp duration_ms(_target), do: nil

  defp track_uri(%Track{provider_ids: %{spotify: id}}) when is_binary(id), do: "spotify:track:" <> id
  defp track_uri(%Single{provider_ids: %{spotify: id}}) when is_binary(id), do: "spotify:track:" <> id
  defp track_uri(%PlaylistTrack{provider: :spotify, track_id: id}) when is_binary(id), do: "spotify:track:" <> id
  defp track_uri(_target), do: nil

  # Every snapshot at debug level; at info level only what changed (first snapshot, playback, device or track).
  defp log_snapshot(data, seq, snapshot, state) do
    Logger.debug(
      "Desktop player snapshot user=#{user(data)} seq=#{seq} position_ms=#{snapshot.position_ms} length_ms=#{snapshot.length_ms} volume=#{inspect(snapshot.volume)}"
    )

    if data.last_seq == -1 or changed?(data.state, state) do
      Logger.info(
        "Desktop player state user=#{user(data)} running=#{snapshot.running} playback=#{snapshot.playback} uri=#{inspect(snapshot.uri)} title=#{inspect(snapshot.title)} artist=#{inspect(snapshot.artist)} album=#{inspect(snapshot.album)}"
      )
    end
  end

  defp changed?(old, new) do
    {old.is_playing, old.device == nil, old.item && old.item.uri} != {new.is_playing, new.device == nil, new.item && new.item.uri}
  end

  defp log_fallback(data, command, detail) do
    Logger.info("Desktop player command falls back to the Web API user=#{user(data)} command=#{command} #{detail}")
  end

  defp command_name(command) when is_atom(command), do: command
  defp command_name(command) when is_tuple(command), do: elem(command, 0)
  defp command_name(_command), do: :unknown

  defp user(%{scope: %{user: %{id: id}}}), do: id

  defp schedule_stale_check(data), do: Map.put(data, :stale_timer, Process.send_after(self(), :stale_check, @stale_check_ms))

  defp now, do: System.monotonic_time(:millisecond)
end
