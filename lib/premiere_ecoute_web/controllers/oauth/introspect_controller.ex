defmodule PremiereEcouteWeb.Oauth.IntrospectController do
  @behaviour Boruta.Oauth.IntrospectApplication

  use PremiereEcouteWeb, :controller

  alias Boruta.Oauth.Error
  alias Boruta.Oauth.IntrospectResponse

  def oauth_module, do: Application.get_env(:premiere_ecoute, :oauth_module, Boruta.Oauth)

  def introspect(%Plug.Conn{} = conn, _params) do
    conn |> oauth_module().introspect(__MODULE__)
  end

  @impl Boruta.Oauth.IntrospectApplication
  def introspect_success(conn, %IntrospectResponse{active: false}) do
    json(conn, %{active: false})
  end

  def introspect_success(conn, %IntrospectResponse{} = response) do
    json(conn, %{
      active: true,
      client_id: response.client_id,
      username: response.username,
      scope: response.scope,
      sub: response.sub,
      iss: response.iss,
      exp: response.exp,
      iat: response.iat
    })
  end

  @impl Boruta.Oauth.IntrospectApplication
  def introspect_error(conn, %Error{
        status: status,
        error: error,
        error_description: error_description
      }) do
    conn
    |> put_status(status)
    |> json(%{error: error, error_description: error_description})
  end
end
