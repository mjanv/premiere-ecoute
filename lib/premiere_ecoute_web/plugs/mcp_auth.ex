defmodule PremiereEcouteWeb.Plugs.McpAuth do
  @moduledoc """
  Gates `/mcp` behind authentication so MCP clients (e.g. claude.ai custom connectors) discover
  that OAuth is required.

  Accepts either the long-lived `x-api-key` header (for CLI agents like Claude Code) or an OAuth
  `Authorization: Bearer` access token issued by Boruta. On failure, halts with 401 and a
  `WWW-Authenticate` header pointing at our RFC 9728 protected-resource metadata — this is the
  signal MCP clients rely on to trigger the OAuth flow instead of silently connecting unauthenticated.
  """

  import Plug.Conn

  alias PremiereEcouteWeb.Mcp.Server

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    api_key = get_req_header(conn, "x-api-key")
    authorization = get_req_header(conn, "authorization")

    case Server.authenticate(api_key, authorization) do
      {:ok, _user} -> conn
      :error -> unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    issuer = Boruta.Config.issuer()
    resource_metadata_url = issuer <> "/.well-known/oauth-protected-resource"

    conn
    |> put_resp_header("www-authenticate", "Bearer resource_metadata=\"#{resource_metadata_url}\"")
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: "unauthorized"})
    |> halt()
  end
end
