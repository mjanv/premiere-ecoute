defmodule PremiereEcouteWeb.Oauth.TokenController do
  @moduledoc """
  OAuth 2.0 token endpoint, delegated to Boruta.
  """

  @behaviour Boruta.Oauth.TokenApplication

  use PremiereEcouteWeb, :controller

  alias Boruta.Oauth.Error
  alias Boruta.Oauth.TokenResponse

  @doc """
  Returns the module handling OAuth requests, overridable in tests.
  """
  @spec oauth_module() :: module()
  def oauth_module, do: Application.get_env(:premiere_ecoute, :oauth_module, Boruta.Oauth)

  @doc """
  Issues an access token.
  """
  @spec token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def token(%Plug.Conn{} = conn, _params) do
    conn |> oauth_module().token(__MODULE__)
  end

  @impl Boruta.Oauth.TokenApplication
  def token_success(conn, %TokenResponse{} = response) do
    body =
      %{
        token_type: response.token_type,
        access_token: response.access_token,
        expires_in: response.expires_in,
        refresh_token: response.refresh_token,
        id_token: response.id_token
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    conn
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("cache-control", "no-store")
    |> json(body)
  end

  @impl Boruta.Oauth.TokenApplication
  def token_error(conn, %Error{status: status, error: error, error_description: error_description}) do
    conn
    |> put_status(status)
    |> json(%{error: error, error_description: error_description})
  end
end
