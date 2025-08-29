defmodule PremiereEcoute.Apis.TidalApi.Accounts do
  @moduledoc """
  # Spotify OAuth2 Authentication

  Handles OAuth2 authentication flows with Spotify Web API, supporting both client credentials flow for public data access and authorization code flow for user-specific operations. Manages token generation, exchange, and refresh operations with comprehensive error handling and logging.
  """

  require Logger

  alias PremiereEcoute.Apis.TidalApi

  def client_credentials do
    TidalApi.accounts()
    |> TidalApi.post(url: "/oauth2/token", body: "grant_type=client_credentials")
    |> TidalApi.handle(200, fn %{"access_token" => _} = body -> body end)
  end
end
