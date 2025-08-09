defmodule PremiereEcoute.Apis.Workers.RenewSpotifyTokens do
  @moduledoc false

  use PremiereEcouteCore.Worker, queue: :spotify, max_attempts: 20

  require Logger

  alias PremiereEcoute.Apis.SpotifyApi.Accounts

  @interval 3_600 - 300

  @impl true
  def perform(%Oban.Job{args: args, attempt: attempt}) do
    case Accounts.client_credentials() do
      {:ok, _} ->
        Logger.info("Spotify tokens renewal successful. Next renewal in #{@interval} seconds.")
        __MODULE__.in_seconds(args, @interval)
        :ok

      {:error, _} ->
        Logger.error("Spotify tokens renewal failed. Attempt #{attempt}/20 Will retry in 10 seconds.")
        {:snooze, 10}
    end
  end
end
