defmodule PremiereEcoute.Apis.Workers.SubscribeStreamEvents do
  @moduledoc """
  Oban worker that subscribes all streamers to stream.online and stream.offline events.

  This worker is scheduled to run at application startup via Oban Cron (@reboot).
  It queries all users with role :streamer and subscribes them to Twitch EventSub
  notifications for stream status changes.
  """

  use PremiereEcouteCore.Worker, queue: :twitch, max_attempts: 3

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.TwitchApi.EventSub

  @impl true
  def perform(%Oban.Job{attempt: attempt}) do
    streamers = User.all(where: [role: :streamer])

    Logger.info("Subscribing #{length(streamers)} streamers to stream events (attempt #{attempt}/3)")

    results =
      streamers
      |> Enum.map(&subscribe_streamer/1)
      |> Enum.group_by(fn {status, _} -> status end)

    successful = length(Map.get(results, :ok, []))
    failed = length(Map.get(results, :error, []))

    Logger.info("Stream event subscription complete: #{successful} successful, #{failed} failed")

    # AIDEV-NOTE: Job succeeds even if some subscriptions fail to avoid blocking startup
    case failed do
      0 ->
        :ok
      _ ->
        Logger.warning("Failed subscriptions: #{inspect(Map.get(results, :error, []))}")
        :ok
    end
  end

  # AIDEV-NOTE: Subscribes a single streamer to both stream.online and stream.offline events
  defp subscribe_streamer(%User{twitch: nil} = user) do
    Logger.warning("Skipping user #{user.id} - no Twitch OAuth token")
    {:error, {:no_twitch_token, user.id}}
  end

  defp subscribe_streamer(%User{} = user) do
    scope = Scope.for_user(user)
    username = user.twitch.username

    with {:ok, _} <- EventSub.subscribe(scope, "stream.online"),
         {:ok, _} <- EventSub.subscribe(scope, "stream.offline") do
      Logger.info("Subscribed streamer: #{username} (ID: #{user.id})")
      {:ok, user.id}
    else
      {:error, reason} = error ->
        Logger.error("Failed to subscribe streamer #{username} (ID: #{user.id}): #{inspect(reason)}")
        {:error, {user.id, reason}}
    end
  end
end
