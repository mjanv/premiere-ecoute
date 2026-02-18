defmodule PremiereEcoute.Accounts.Workers.RenewSpotifyTokens do
  @moduledoc """
  Oban worker for automatic Spotify token renewal.

  Periodically refreshes Spotify API client credentials, schedules next renewal 5 minutes before expiration, and retries on failure with 10-second snooze intervals.
  """

  use PremiereEcouteCore.Worker, queue: :tokens, max_attempts: 5

  require Logger

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Accounts

  @impl true
  def perform(%Oban.Job{args: args, attempt: attempt}) do
    case Accounts.client_credentials() do
      {:ok, %{"expires_in" => expires_in}} ->
        interval = expires_in - 300
        Logger.info("Spotify tokens renewal successful. Next renewal in #{interval} seconds.")
        __MODULE__.in_seconds(args, interval)
        :ok

      {:error, _} ->
        Logger.error("Spotify tokens renewal failed. Attempt #{attempt}/20 Will retry in 10 seconds.")
        {:snooze, 10}
    end
  end
end
