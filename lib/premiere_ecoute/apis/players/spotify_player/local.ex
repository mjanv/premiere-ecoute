defmodule PremiereEcoute.Apis.Players.SpotifyPlayer.Local do
  @moduledoc """
  Local mode of the Spotify player.

  Follows the desktop player connected by the streamer: no polling, the playback state comes from the snapshots it pushes. Falls back to the Api mode when the device disconnects or goes silent.
  """

  @behaviour PremiereEcoute.Apis.Players.SpotifyPlayer.Mode

  alias PremiereEcoute.Apis.Players.PlaybackState

  @stale_after_ms 5_000
  @stale_check_ms 1_000
  @keys [:device, :last_seq, :last_seen_ms, :stale_timer]

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
      last_seen_ms: now()
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

  def handle_info(_message, data), do: {:noreply, data}

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
