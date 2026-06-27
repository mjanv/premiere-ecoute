defmodule PremiereEcouteWeb.Oauth.DiscoveryController do
  @moduledoc """
  OAuth 2.0 Authorization Server Metadata (RFC 8414), served at
  `/.well-known/oauth-authorization-server`, so MCP clients (e.g. claude.ai custom connectors)
  can discover our endpoints from the MCP server URL alone.
  """

  use PremiereEcouteWeb, :controller

  def show(conn, _params) do
    issuer = Boruta.Config.issuer()

    json(conn, %{
      issuer: issuer,
      authorization_endpoint: issuer <> "/oauth/authorize",
      token_endpoint: issuer <> "/oauth/token",
      registration_endpoint: issuer <> "/oauth/register",
      revocation_endpoint: issuer <> "/oauth/revoke",
      introspection_endpoint: issuer <> "/oauth/introspect",
      response_types_supported: ["code"],
      grant_types_supported: ["authorization_code", "refresh_token"],
      code_challenge_methods_supported: ["S256"],
      token_endpoint_auth_methods_supported: ["client_secret_post", "client_secret_basic", "none"],
      scopes_supported: ["mcp"]
    })
  end
end
