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
  alias PremiereEcoute.Apis.Players.SpotifyPlayer

  @poll_interval 1_000
  @poll_max_hours 9
  @polls trunc(@poll_max_hours * 3_600_000 / @poll_interval)

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
         {:ok, new_state} <- Apis.spotify().get_playback_state(scope, old_state) do
      data = schedule_poll(data, @poll_interval)
      {:observe, new_state, %{data | scope: scope, polls: polls - 1, failures: 0}}
    else
      {:error, reason} ->
        data = register_failure(data, reason)
        data = schedule_poll(data, poll_interval(data.failures))
        {:noreply, %{data | polls: polls - 1}}
    end
  end

  def handle_info(:no_overlay, data), do: {:stop, :normal, data}

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
