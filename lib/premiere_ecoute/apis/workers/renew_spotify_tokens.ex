defmodule PremiereEcoute.Apis.Workers.RenewSpotifyTokens do
  @moduledoc false

  use PremiereEcoute.Core.Worker, queue: :spotify, max_attempts: 20

  alias PremiereEcoute.Apis.SpotifyApi.Accounts

  @impl true
  def perform(%Oban.Job{args: args}) do
    case Accounts.client_credentials() do
      {:ok, _} ->
        __MODULE__.in_seconds(args, 3_600 - 300)
        :ok

      {:error, _} ->
        {:snooze, 10}
    end
  end
end
