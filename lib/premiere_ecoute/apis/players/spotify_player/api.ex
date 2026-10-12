defmodule PremiereEcoute.Apis.Players.SpotifyPlayer.Api do
  @moduledoc """
  Api mode of the Spotify player.

  Polls the Spotify Web API every second, renews the access token, backs off on failures and stops after a poll budget.
  """

  @behaviour PremiereEcoute.Apis.Players.SpotifyPlayer.Mode

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.NotConnectedError
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Apis.Players.SpotifyPlayer

  @poll_interval 1_000
  @poll_max_hours 9
  @polls trunc(@poll_max_hours * 3_600_000 / @poll_interval)

  @idle_ms 300_000

  @degraded_after 3
  @down_after 20
  @max_backoff_interval 5_000

  @doc "Interval between two polls when the Web API answers."
  @spec poll_interval() :: pos_integer()
  def poll_interval, do: @poll_interval

  @doc "Number of polls before the player stops."
  @spec polls() :: pos_integer()
  def polls, do: @polls

  @doc """
  Enters the api mode with a fresh poll budget and polls right away.
  """
  @spec enter(map()) :: map()
  def enter(data) do
    data
    |> Map.merge(%{mode: :api, state: PlaybackState.default(), polls: @polls, failures: 0})
    |> schedule_poll(0)
  end

  @doc """
  Leaves the api mode: cancels the scheduled poll.
  """
  @spec leave(map()) :: map()
  def leave(data) do
    for key <- [:poll_timer, :idle_timer], timer = data[key], do: Process.cancel_timer(timer)
    Map.drop(data, [:poll_timer, :idle_timer])
  end

  @doc """
  Fetches the playback state from the Web API.

  A user without a linked Spotify account has no Web API access, which is reported as `{:error, :not_connected}` instead of raising.
  """
  @spec fetch(Scope.t(), PlaybackState.t()) :: {:ok, PlaybackState.t()} | {:error, term()}
  def fetch(scope, old_state) do
    Apis.spotify().get_playback_state(scope, old_state)
  rescue
    NotConnectedError -> {:error, :not_connected}
  end

  @doc """
  Stops polling and waits for a desktop player to attach, stopping the player after an idle timeout.
  """
  @spec idle(map()) :: map()
  def idle(data) do
    data = Map.delete(data, :poll_timer)
    Map.put_new_lazy(data, :idle_timer, fn -> Process.send_after(self(), :idle_timeout, @idle_ms) end)
  end

  @doc """
  Schedules the next poll.
  """
  @spec schedule_poll(map(), non_neg_integer()) :: map()
  def schedule_poll(data, interval) do
    Map.put(data, :poll_timer, Process.send_after(self(), :poll, interval))
  end

  @impl true
  def handle_info(:poll, %{scope: scope, polls: 0} = data) do
    Logger.warning("Spotify player budget exhausted for user #{scope.user.id}, stopping normally")
    {:stop, :normal, data}
  end

  def handle_info(:poll, %{scope: scope, state: old_state, polls: polls} = data) do
    with {:ok, scope} <- maybe_renew_token(scope),
         {:ok, new_state} <- fetch(scope, old_state) do
      data = schedule_poll(data, @poll_interval)
      {:observe, new_state, %{data | scope: scope, polls: polls - 1, failures: 0}}
    else
      {:error, :not_connected} ->
        {:noreply, idle(data)}

      {:error, reason} ->
        data = register_failure(data, reason)
        data = schedule_poll(data, poll_interval(data.failures))
        {:noreply, %{data | polls: polls - 1}}
    end
  end

  def handle_info(:no_overlay, data), do: {:stop, :normal, data}

  def handle_info(:idle_timeout, data), do: {:stop, :normal, data}

  def handle_info(_message, data), do: {:noreply, data}

  @doc """
  Registers a failed poll and publishes the degraded or down status when reached.
  """
  @spec register_failure(map(), term()) :: map()
  def register_failure(%{state: state, failures: failures, scope: scope} = data, reason) do
    failures = failures + 1
    status = status_for(failures)
    state = %{state | status: status}
    interval = poll_interval(failures)

    Logger.warning(
      "Spotify player poll failed for user #{scope.user.id} (#{failures} consecutive failures, status: #{status}, retrying in #{interval}ms): #{inspect(reason)}"
    )

    if status != :normal, do: SpotifyPlayer.publish(scope, status, state)

    %{data | state: state, failures: failures}
  end

  @doc """
  Interval before the next poll, growing with consecutive failures.
  """
  @spec poll_interval(non_neg_integer()) :: pos_integer()
  def poll_interval(failures) when failures < @degraded_after, do: @poll_interval

  def poll_interval(failures) do
    interval = @poll_interval * trunc(:math.pow(2, failures - @degraded_after + 1))
    min(interval, @max_backoff_interval)
  end

  defp maybe_renew_token(old_scope) do
    scope = Accounts.maybe_renew_token(old_scope, :spotify)
    if at(scope) != at(old_scope), do: SpotifyPlayer.publish(scope, :token_refreshed, scope)
    {:ok, scope}
  end

  defp at(%Scope{user: %{spotify: %{access_token: access_token}}}), do: access_token
  defp at(_), do: nil

  defp status_for(failures) when failures >= @down_after, do: :down
  defp status_for(failures) when failures >= @degraded_after, do: :degraded
  defp status_for(_failures), do: :normal
end
