defmodule PremiereEcouteWeb.Oauth.RevokeController do
  @behaviour Boruta.Oauth.RevokeApplication

  use PremiereEcouteWeb, :controller

  alias Boruta.Oauth.Error

  def oauth_module, do: Application.get_env(:premiere_ecoute, :oauth_module, Boruta.Oauth)

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
