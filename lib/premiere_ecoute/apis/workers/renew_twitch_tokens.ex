defmodule PremiereEcoute.Apis.Workers.RenewTwitchTokens do
  @moduledoc false

  use PremiereEcouteCore.Worker, queue: :twitch, max_attempts: 20

  require Logger

  alias PremiereEcoute.Apis.TwitchApi.Accounts

  @impl true
  def perform(%Oban.Job{args: args, attempt: attempt}) do
    case Accounts.client_credentials() do
      {:ok, %{"expires_in" => expires_in}} ->
        interval = expires_in - 300
        Logger.info("Twitch tokens renewal successful. Next renewal in #{interval} seconds.")
        __MODULE__.in_seconds(args, interval)
        :ok

      {:error, _} ->
        Logger.error("Twitch tokens renewal failed. Attempt #{attempt}/20 Will retry in 10 seconds.")
        {:snooze, 10}
    end
  end
end
