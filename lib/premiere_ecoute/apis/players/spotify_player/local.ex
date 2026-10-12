defmodule PremiereEcoute.Apis.Players.SpotifyPlayer.Local do
  @moduledoc """
  Local mode of the Spotify player.

  Follows the desktop player connected by the streamer: no polling, the playback state comes from the snapshots it pushes. Falls back to the Api mode when the device disconnects or goes silent.
  """

  @behaviour PremiereEcoute.Apis.Players.SpotifyPlayer.Mode

  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Playlist.Track, as: PlaylistTrack
  alias PremiereEcoute.Discography.Single

  @stale_after_ms 5_000
  @stale_check_ms 1_000
  @command_ttl_ms 10_000
  @command_grace_ms 2_000
  @keys [:device, :last_seq, :last_seen_ms, :stale_timer, :pending]

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
    for {_id, {from, timer, _result}} <- data.pending do
      Process.cancel_timer(timer)
      GenServer.reply(from, {:error, :unknown})
    end

    Map.drop(data, @keys)
  end

  def leave(data), do: Map.drop(data, @keys)

  @impl true
  def handle_info({:device_snapshot, seq, snapshot}, %{last_seq: last_seq} = data) when seq > last_seq do
    {:observe, to_playback_state(snapshot), %{data | last_seq: seq, last_seen_ms: now()}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{device: %{ref: ref}} = data), do: {:switch, :api, data}

  def handle_info(:stale_check, %{last_seen_ms: last_seen_ms} = data) do
    if now() - last_seen_ms > @stale_after_ms do
      {:switch, :api, data}
    else
      {:noreply, schedule_stale_check(data)}
    end
  end

  def handle_info({:device_ack, id, status, _error}, data) do
    case Map.pop(data.pending, id) do
      {nil, _pending} ->
        {:noreply, data}

      {{from, timer, result}, pending} ->
        Process.cancel_timer(timer)
        GenServer.reply(from, reply(status, result))
        {:noreply, %{data | pending: pending}}
    end
  end

  def handle_info({:command_expired, id}, data) do
    case Map.pop(data.pending, id) do
      {nil, _pending} ->
        {:noreply, data}

      {{from, _timer, _result}, pending} ->
        GenServer.reply(from, {:error, :unknown})
        {:noreply, %{data | pending: pending}}
    end
  end

  def handle_info(_message, data), do: {:noreply, data}

  # `:rejected`, `:expired` and `:error` guarantee that the command was not executed: the Web API takes over.
  defp reply(:ok, result), do: result
  defp reply(status, _result) when status in [:rejected, :expired, :error], do: :api
  defp reply(_status, _result), do: {:error, :unknown}

  @impl true
  def command({:play, target}, from, data) do
    case track_uri(target) do
      nil -> {:reply, :api, data}
      uri -> push(data, from, :play_uri, %{uri: uri}, {:ok, uri})
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
  def command(:active_device, _from, %{last_seq: -1} = data), do: {:reply, :api, data}
  def command(:active_device, _from, %{state: %{device: nil}} = data), do: {:reply, {:error, :no_active_device}, data}
  def command(:active_device, _from, data), do: {:reply, {:ok, :active}, data}

  # The desktop player plays one track at a time, there is no shuffle nor repeat to reset.
  def command({:shuffle, _shuffle}, _from, data), do: {:reply, {:ok, :skipped}, data}
  def command({:repeat, _mode}, _from, data), do: {:reply, {:ok, :skipped}, data}

  def command(_command, _from, data), do: {:reply, :api, data}

  defp push(%{device: %{pid: pid}} = data, from, type, args, result) do
    id = UUID.uuid4()
    send(pid, {:command, %{id: id, type: type, args: args, ttl_ms: @command_ttl_ms}})
    timer = Process.send_after(self(), {:command_expired, id}, @command_ttl_ms + @command_grace_ms)
    {:noreply, %{data | pending: Map.put(data.pending, id, {from, timer, result})}}
  end

  defp track_uri(%Track{provider_ids: %{spotify: id}}) when is_binary(id), do: "spotify:track:" <> id
  defp track_uri(%Single{provider_ids: %{spotify: id}}) when is_binary(id), do: "spotify:track:" <> id
  defp track_uri(%PlaylistTrack{provider: :spotify, track_id: id}) when is_binary(id), do: "spotify:track:" <> id
  defp track_uri(_target), do: nil

  defp schedule_stale_check(data), do: Map.put(data, :stale_timer, Process.send_after(self(), :stale_check, @stale_check_ms))

  defp now, do: System.monotonic_time(:millisecond)

  defp to_playback_state(snapshot) do
    %PlaybackState{
      is_playing: snapshot.playback == :playing,
      progress_ms: snapshot.position_ms,
      device: if(snapshot.running, do: %{name: "Desktop", is_active: true}),
      item: item(snapshot),
      status: :normal
    }
  end

  defp item(%{uri: nil}), do: PlaybackState.default().item

  defp item(snapshot) do
    %{
      uri: snapshot.uri,
      name: snapshot.title,
      duration_ms: max(snapshot.length_ms, 1),
      artists: [%{name: snapshot.artist}],
      type: :album,
      track_number: nil,
      album: %{name: snapshot.album, total_tracks: 0, images: []}
    }
  end
end
