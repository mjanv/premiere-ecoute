defmodule PremiereEcoute.Apis.Players.SpotifyPlayer do
  @moduledoc """
  Spotify playback state monitoring GenServer.

  Polls the Spotify API every second to track playback state changes and broadcasts events for play/pause, track changes, and playback progress to user-specific PubSub channels.
  """

  use GenServer, restart: :transient

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Presence

  @registry PremiereEcoute.Apis.Players.PlayerRegistry
  @poll_interval 1_000
  @poll_max_hours 9
  @polls trunc(@poll_max_hours * 3_600_000 / @poll_interval)

  @degraded_after 3
  @down_after 20
  @max_backoff_interval 5_000

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
    data = %{scope: scope, state: PlaybackState.default(), polls: @polls, failures: 0}

    with {:ok, phx_ref} <- Presence.join(scope.user.id, :player),
         :ok <- PremiereEcoute.PubSub.subscribe("player:#{scope.user.id}"),
         {:ok, state} <- Apis.spotify().get_playback_state(scope, PlaybackState.default()) do
      Process.send_after(self(), :poll, @poll_interval)
      {:ok, Map.merge(data, %{phx_ref: phx_ref, state: state})}
    else
      {:error, reason} ->
        data = register_failure(Map.put(data, :phx_ref, nil), reason)
        Process.send_after(self(), :poll, poll_interval(data.failures))
        {:ok, data}
    end
  end

  @impl true
  def handle_info(:poll, %{scope: scope, polls: 0} = data) do
    Logger.warning("Spotify player budget exhausted for user #{scope.user.id}, stopping normally")
    {:stop, :normal, data}
  end

  def handle_info(:poll, %{scope: scope, state: old_state, polls: polls} = data) do
    with {:ok, scope} <- maybe_renew_token(scope),
         {:ok, new_state} <- Apis.spotify().get_playback_state(scope, old_state),
         {:ok, state, events} <- handle(old_state, %{new_state | status: :normal}),
         :ok <- Enum.each(events, fn event -> publish(scope, event, state) end) do
      Process.send_after(self(), :poll, @poll_interval)
      {:noreply, %{data | scope: scope, state: state, polls: polls - 1, failures: 0}}
    else
      {:error, reason} ->
        data = register_failure(%{data | scope: scope}, reason)
        Process.send_after(self(), :poll, poll_interval(data.failures))
        {:noreply, %{data | polls: polls - 1}}
    end
  end

  @impl true
  def handle_info(:no_overlay, data) do
    {:stop, :normal, data}
  end

  @impl true
  def terminate(:normal, _), do: :ok

  @impl true
  def terminate(reason, %{scope: scope, state: state}) do
    Logger.warning("Stop Spotify player due to: #{inspect(reason)}")
    publish(scope, reason, state)

    :ok
  end

  defp maybe_renew_token(old_scope) do
    scope = Accounts.maybe_renew_token(old_scope, :spotify)
    if at(scope) != at(old_scope), do: publish(scope, :token_refreshed, scope)
    {:ok, scope}
  end

  defp at(%Scope{user: %{spotify: %{access_token: access_token}}}), do: access_token
  defp at(_), do: nil

  defp publish(scope, event, state) do
    PremiereEcoute.PubSub.broadcast("playback:#{scope.user.id}", {:player, event, state})
  end

  defp register_failure(%{state: state, failures: failures, scope: scope} = data, reason) do
    failures = failures + 1
    status = status_for(failures)
    state = %{state | status: status}
    interval = poll_interval(failures)

    Logger.warning(
      "Spotify player poll failed for user #{scope.user.id} (#{failures} consecutive failures, status: #{status}, retrying in #{interval}ms): #{inspect(reason)}"
    )

    if status != :normal, do: publish(scope, status, state)

    %{data | state: state, failures: failures}
  end

  defp status_for(failures) when failures >= @down_after, do: :down
  defp status_for(failures) when failures >= @degraded_after, do: :degraded
  defp status_for(_failures), do: :normal

  defp poll_interval(failures) when failures < @degraded_after, do: @poll_interval

  defp poll_interval(failures) do
    interval = @poll_interval * trunc(:math.pow(2, failures - @degraded_after + 1))
    min(interval, @max_backoff_interval)
  end

  @doc """
  Calculates playback progress as a percentage.

  Returns playback progress percentage (0-100) from current position and total track duration in playback state.
  """
  @spec progress(PlaybackState.t()) :: integer()
  def progress(%PlaybackState{item: %{duration_ms: duration_ms}, progress_ms: progress_ms}) do
    if duration_ms - progress_ms <= @poll_interval do
      100
    else
      trunc(100 * (progress_ms / (duration_ms + 1)))
    end
  end

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

  def handle(old_state, new_state) do
    case {progress(old_state), progress(new_state)} do
      {0, b} when b >= 1 -> {:ok, new_state, [:start_track]}
      {a, b} when a < 99 and b >= 99 -> {:ok, new_state, [:end_track]}
      {a, b} when abs(b - a) > 5 -> {:ok, new_state, [{:skip, b}]}
      {a, b} when b > a -> {:ok, new_state, [{:percent, b}]}
      _ -> {:ok, new_state, []}
    end
  end
end
