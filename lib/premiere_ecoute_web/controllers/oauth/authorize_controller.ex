defmodule PremiereEcouteWeb.Oauth.AuthorizeController do
  @moduledoc """
  OAuth 2.1 authorize endpoint with a consent screen.

  `GET /oauth/authorize` validates the request (client, redirect_uri, scope, PKCE) via
  `Boruta.Oauth.preauthorize/3` and shows a consent screen. Approving it issues a `POST` back to
  this same path, which calls `Boruta.Oauth.authorize/3` to mint the authorization code and
  redirect to the client's `redirect_uri`. Denying redirects back with `error=access_denied`.
  """

  @behaviour Boruta.Oauth.AuthorizeApplication

  use PremiereEcouteWeb, :controller

  alias Boruta.Oauth.AuthorizationSuccess
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.ResourceOwner
  alias PremiereEcouteWeb.Oauth.AuthorizeHTML

  def authorize(%Plug.Conn{params: %{"approved" => "true"}} = conn, _params) do
    conn
    |> Boruta.Oauth.authorize(resource_owner(conn), __MODULE__)
  end

  def authorize(%Plug.Conn{params: %{"approved" => "false"}} = conn, _params) do
    deny(conn)
  end

  def authorize(%Plug.Conn{} = conn, _params) do
    conn
    |> Boruta.Oauth.preauthorize(resource_owner(conn), __MODULE__)
  end

  @impl Boruta.Oauth.AuthorizeApplication
  def preauthorize_success(conn, %AuthorizationSuccess{client: client, scope: scope}) do
    conn
    |> put_view(AuthorizeHTML)
    |> render(:consent, client: client, scope: scope, query_string: conn.query_string)
  end

  @impl Boruta.Oauth.AuthorizeApplication
  def preauthorize_error(conn, %Error{} = error), do: render_error(conn, error)

  @impl Boruta.Oauth.AuthorizeApplication
  def authorize_success(conn, %AuthorizeResponse{} = response) do
    redirect(conn, external: AuthorizeResponse.redirect_to_url(response))
  end

  @impl Boruta.Oauth.AuthorizeApplication
  def authorize_error(conn, %Error{format: format} = error) when not is_nil(format) do
    redirect(conn, external: Error.redirect_to_url(error))
  end

  def authorize_error(conn, %Error{} = error), do: render_error(conn, error)

  defp resource_owner(%Plug.Conn{assigns: %{current_scope: %{user: user}}}) do
    %ResourceOwner{sub: to_string(user.id), username: user.email}
  end

  defp deny(%Plug.Conn{query_params: %{"redirect_uri" => redirect_uri, "state" => state}} = conn) do
    redirect(conn,
      external:
        redirect_uri <>
          "?error=access_denied&error_description=The+resource+owner+denied+the+request&state=#{URI.encode_www_form(state)}"
    )
  end

  defp deny(%Plug.Conn{query_params: %{"redirect_uri" => redirect_uri}} = conn) do
    redirect(conn, external: redirect_uri <> "?error=access_denied&error_description=The+resource+owner+denied+the+request")
  end

  defp deny(conn) do
    render_error(conn, %Error{
      status: :bad_request,
      error: :invalid_request,
      error_description: "Missing redirect_uri."
    })
  end

  defp render_error(conn, %Error{status: status, error: error, error_description: error_description}) do
    conn
    |> put_status(status)
    |> put_view(AuthorizeHTML)
    |> render(:error, error: error, error_description: error_description)
  end
end
