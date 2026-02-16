defmodule PremiereEcoute.Apis.MusicProvider.TidalApi.Accounts do
  @moduledoc """
  # Tidal OAuth2 Authentication

  Handles OAuth2 authentication flows with Tidal API, supporting client credentials flow for public data access. Manages token generation with comprehensive error handling and logging.
  """

  require Logger

  alias PremiereEcoute.Apis.MusicProvider.TidalApi

  @doc """
  Obtains Tidal application access token using client credentials flow.

  Uses OAuth2 client credentials grant for server-to-server API authentication without user authorization.
  """
  @spec client_credentials() :: {:ok, map()} | {:error, term()}
  def client_credentials do
    TidalApi.accounts()
    |> TidalApi.post(url: "/oauth2/token", body: "grant_type=client_credentials")
    |> TidalApi.handle(200, fn %{"access_token" => _} = body -> body end)
  end
end
