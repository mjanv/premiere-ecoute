defmodule PremiereEcoute.Apis.Players.SpotifyPlayer do
  @moduledoc """
  Spotify playback state monitoring GenServer.

  Polls the Spotify API every second to track playback state changes and broadcasts events for play/pause, track changes, and playback progress to user-specific PubSub channels.
  """

  use GenServer, restart: :transient

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Apis.Players.SpotifyPlayer.Api
  alias PremiereEcoute.Apis.Players.SpotifyPlayer.Local
  alias PremiereEcoute.Presence

  @registry PremiereEcoute.Apis.Players.PlayerRegistry
  @command_timeout 15_000

  @doc """
  Starts the Spotify player monitoring GenServer.

  Launches a GenServer registered via Registry to monitor Spotify playback state for a specific user.
  """
  @spec start_link(integer()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: {:via, Registry, {@registry, args}})
  end

  @doc false
  @spec init(integer()) :: {:ok, map()}
  @impl true
  def init(args) do
    scope = Scope.for_user(User.get(args))
    data = %{scope: scope, state: PlaybackState.default(), polls: Api.polls(), failures: 0}

    with {:ok, phx_ref} <- Presence.join(scope.user.id, :player),
         :ok <- PremiereEcoute.PubSub.subscribe("player:#{scope.user.id}"),
         {:ok, state} <- Api.fetch(scope, PlaybackState.default()) do
      {:ok, Api.schedule_poll(Map.merge(data, %{phx_ref: phx_ref, state: state}), Api.poll_interval())}
    else
      {:error, :not_connected} ->
        {:ok, Api.idle(Map.put(data, :phx_ref, nil))}

      {:error, reason} ->
        data = register_failure(Map.put(data, :phx_ref, nil), reason)
        {:ok, Api.schedule_poll(data, Api.poll_interval(data.failures))}
    end
  end

  @doc """
  Runs a playback command through the user's local player when there is one, through the Web API otherwise.

  `fallback` runs the command through the Web API. It is called when the user has no player, when the player is in Api mode, or when the local player did not execute the command (unsupported, rejected, expired). It is never called when the local player may have executed it: that case returns `{:error, :unknown}`, as a blind retry could double-toggle or skip two tracks.
  """
  @spec command(Scope.t(), term(), (-> result)) :: result | {:error, :unknown} when result: term()
  def command(%Scope{user: %{id: user_id}}, command, fallback) when is_function(fallback, 0) do
    with pid when is_pid(pid) <- player(user_id),
         :api <- call(pid, command) do
      fallback.()
    else
      nil -> fallback.()
      result -> result
    end
  end

  defp player(user_id) do
    with pid when is_pid(pid) <- Process.whereis(@registry),
         [{player, _value} | _] <- Registry.lookup(@registry, user_id) do
      player
    else
      _ -> nil
    end
  end

  defp call(pid, command) do
    GenServer.call(pid, {:command, command}, @command_timeout)
  catch
    :exit, {:noproc, _} -> :api
    :exit, _ -> {:error, :unknown}
  end

  @doc false
  @impl true
  def handle_call({:command, command}, from, data), do: mode(data).command(command, from, data)

  @doc false
  @impl true
  def handle_info({:device_attached, pid, meta}, data), do: {:noreply, attach(data, pid, meta)}

  def handle_info(message, data) do
    case mode(data).handle_info(message, data) do
      {:observe, new_state, data} -> observe(data, new_state)
      {:noreply, data} -> {:noreply, data}
      {:switch, :api, data} -> {:noreply, switch_to_api(data)}
      {:stop, reason, data} -> {:stop, reason, data}
    end
  end

  @impl true
  def terminate(:normal, _), do: :ok

  @impl true
  def terminate(reason, %{scope: scope, state: state}) do
    Logger.warning("Stop Spotify player due to: #{inspect(reason)}")
    publish(scope, reason, state)

    :ok
  end

  @doc false
  @spec publish(Scope.t(), term(), term()) :: :ok | {:error, term()}
  def publish(scope, event, state) do
    PremiereEcoute.PubSub.broadcast("playback:#{scope.user.id}", {:player, event, state})
  end

  # The api mode is the default: it is the one the player starts in and the one it falls back to.
  defp mode(%{mode: :local}), do: Local
  defp mode(_data), do: Api

  # A newly attached device replaces the previous one.
  defp attach(%{mode: :local, device: %{pid: previous}} = data, pid, meta) do
    send(previous, {:disconnect, :replaced})
    data |> Local.leave() |> Local.enter(pid, meta) |> publish_mode()
  end

  defp attach(data, pid, meta), do: data |> Api.leave() |> Local.enter(pid, meta) |> publish_mode()

  defp switch_to_api(data), do: data |> Local.leave() |> Api.enter() |> publish_mode()

  defp publish_mode(%{scope: scope, state: state, mode: mode} = data) do
    publish(scope, {:mode, mode}, state)
    data
  end

  defp observe(%{scope: scope, state: old_state} = data, new_state) do
    {:ok, state, events} = handle(old_state, %{new_state | status: :normal})
    Enum.each(events, fn event -> publish(scope, event, state) end)
    {:noreply, %{data | state: state}}
  end

  defp register_failure(data, reason), do: Api.register_failure(data, reason)

  @doc """
  Calculates playback progress as a percentage.

  Returns playback progress percentage (0-100) from current position and total track duration in playback state.
  """
  @spec progress(PlaybackState.t()) :: integer()
  def progress(%PlaybackState{item: %{duration_ms: duration_ms}, progress_ms: progress_ms}) do
    if duration_ms - progress_ms <= Api.poll_interval() do
      100
    else
      trunc(100 * (progress_ms / (duration_ms + 1)))
    end
  end

  def progress(%PlaybackState{item: nil}), do: 0

  @doc """
  Detects playback state changes and generates events.

  Compares old and new playback states to identify transitions (play/pause, track changes, progress updates) and returns the new state with corresponding event list.
  """
  @spec handle(PlaybackState.t(), PlaybackState.t()) :: {:ok, PlaybackState.t(), list()}
  def handle(old_state, new_state) when old_state == %PlaybackState{}, do: {:ok, new_state, []}
  def handle(%PlaybackState{device: nil}, new_state), do: {:ok, new_state, []}
  def handle(_old_state, %PlaybackState{device: nil} = new_state), do: {:ok, new_state, [:no_device]}
  def handle(%PlaybackState{is_playing: false}, %PlaybackState{is_playing: true} = state), do: {:ok, state, [:start]}
  def handle(%PlaybackState{is_playing: true}, %PlaybackState{is_playing: false} = state), do: {:ok, state, [:stop]}

  def handle(%PlaybackState{item: %{uri: uri1}}, %PlaybackState{item: %{uri: uri2}} = state) when uri1 != uri2,
    do: {:ok, state, [:new_track]}

  def handle(_old_state, %PlaybackState{item: nil} = new_state), do: {:ok, new_state, []}

  def handle(old_state, new_state) do
    case {progress(old_state), progress(new_state)} do
      {0, b} when b >= 1 -> {:ok, new_state, [:start_track]}
      {a, b} when a < 99 and b >= 99 -> {:ok, new_state, [:end_track]}
      {a, b} when abs(b - a) > 5 -> {:ok, new_state, [{:skip, {b, new_state.progress_ms, new_state.item.duration_ms}}]}
      {a, b} when b > a -> {:ok, new_state, [{:percent, {b, new_state.progress_ms, new_state.item.duration_ms}}]}
      _ -> {:ok, new_state, []}
    end
  end
end
