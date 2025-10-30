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
  alias PremiereEcoute.Accounts.User.OauthToken
  alias PremiereEcoute.Apis.TwitchApi.EventSub

  @impl true
  def perform(%Oban.Job{attempt: attempt}) do
    streamers = User.all(where: [role: :streamer])
    Logger.info("Subscribing #{length(streamers)} streamers to stream events (attempt #{attempt}/3)")
    Enum.each(streamers, &subscribe_streamer/1)

    :ok
  end

  # AIDEV-NOTE: Made public for testing - tests functional methods directly
  def subscribe_streamer(%User{twitch: %OauthToken{} = twitch} = user) do
    scope = Scope.for_user(user)
    username = twitch.username

    with {:ok, _} <- EventSub.subscribe(scope, "stream.online"),
         {:ok, _} <- EventSub.subscribe(scope, "stream.offline") do
      Logger.info("Subscribed streamer: #{username} (ID: #{user.id})")
      {:ok, user.id}
    else
      {:error, reason} ->
        Logger.error("Failed to subscribe streamer #{username} (ID: #{user.id}): #{inspect(reason)}")
        {:error, {user.id, reason}}
    end
  end

  def subscribe_streamer(%User{} = user) do
    Logger.warning("Skipping user #{user.id} - no Twitch OAuth token")
    {:error, {:no_twitch_token, user.id}}
  end
end
