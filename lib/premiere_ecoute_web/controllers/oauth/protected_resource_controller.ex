defmodule PremiereEcouteWeb.Oauth.ProtectedResourceController do
  @moduledoc """
  OAuth 2.0 Protected Resource Metadata (RFC 9728), served at
  `/.well-known/oauth-protected-resource`, so MCP clients (e.g. claude.ai custom connectors)
  discover that `/mcp` requires OAuth and which authorization server issues its tokens.

  Without this document, an unauthenticated request to `/mcp` would otherwise look like a
  server that doesn't require auth at all, and clients would never trigger the OAuth flow.
  """

  use PremiereEcouteWeb, :controller

  def show(conn, _params) do
    issuer = Boruta.Config.issuer()

    json(conn, %{
      resource: issuer <> "/mcp",
      authorization_servers: [issuer],
      scopes_supported: ["mcp"],
      bearer_methods_supported: ["header"]
    })
  end
end
