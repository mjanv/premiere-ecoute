defmodule PremiereEcouteWeb.Oauth.RevokeController do
  @moduledoc """
  OAuth 2.0 token revocation endpoint (RFC 7009), delegated to Boruta.
  """

  @behaviour Boruta.Oauth.RevokeApplication

  use PremiereEcouteWeb, :controller

  alias Boruta.Oauth.Error

  @doc """
  Returns the module handling OAuth requests, overridable in tests.
  """
  @spec oauth_module() :: module()
  def oauth_module, do: Application.get_env(:premiere_ecoute, :oauth_module, Boruta.Oauth)

  @doc """
  Revokes a token.
  """
  @spec revoke(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def revoke(%Plug.Conn{} = conn, _params) do
    conn |> oauth_module().revoke(__MODULE__)
  end

  @impl Boruta.Oauth.RevokeApplication
  def revoke_success(%Plug.Conn{} = conn) do
    send_resp(conn, 200, "")
  end

  @impl Boruta.Oauth.RevokeApplication
  def revoke_error(conn, %Error{
        status: status,
        error: error,
        error_description: error_description
      }) do
    conn
    |> put_status(status)
    |> json(%{error: error, error_description: error_description})
  end
end
