defmodule PremiereEcouteWeb.Oauth.RegistrationController do
  @moduledoc """
  OAuth 2.0 Dynamic Client Registration (RFC 7591 / OpenID Connect Dynamic Client Registration 1.0).

  Lets remote MCP clients (e.g. claude.ai custom connectors) register themselves against
  `POST /oauth/register` without a human pre-creating a client, so adding the connector only
  requires the MCP server URL — no manually issued Client ID/Secret.
  """

  use PremiereEcouteWeb, :controller

  require Logger

  # AIDEV-NOTE: callbacks (client_registered/2, registration_failure/2) and field names
  # (supported_grant_types, token_endpoint_auth_methods) follow Boruta.Openid.register_client/3's
  # documented contract (boruta ~> 2.3) but are unverified against the compiled source — this repo
  # has no network access to `mix deps.get`. Re-check both against the real module once fetched,
  # and add `@behaviour Boruta.Openid.RegisterApplication` (or whatever it's actually named) back.

  @doc """
  Registers a new OAuth client from the request body and returns its credentials.
  """
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, registration_params) do
    Boruta.Openid.register_client(conn, registration_params, __MODULE__)
  end

  def client_registered(conn, client) do
    conn
    |> put_status(:created)
    |> json(%{
      client_id: client.id,
      client_secret: client.secret,
      client_id_issued_at: DateTime.to_unix(client.inserted_at),
      client_name: client.name,
      redirect_uris: client.redirect_uris,
      grant_types: client.supported_grant_types,
      token_endpoint_auth_method: client.token_endpoint_auth_methods
    })
  end

  def registration_failure(conn, changeset) do
    Logger.warning("OAuth dynamic client registration failed: #{inspect(changeset.errors)}")

    conn
    |> put_status(:bad_request)
    |> json(%{error: "invalid_client_metadata", error_description: "Client registration parameters are invalid."})
  end
end
