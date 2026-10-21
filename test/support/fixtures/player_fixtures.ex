defmodule PremiereEcoute.PlayerFixtures do
  @moduledoc """
  Test helpers for the desktop player: issues real Boruta tokens through the player OAuth client.
  """

  import Ecto.Query, only: [from: 2]

  alias Boruta.Ecto.Token
  alias Boruta.Ecto.TokenStore
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Oauth.TokenResponse
  alias PremiereEcoute.Devices.OauthClient

  @redirect_uri "http://127.0.0.1:53682/cb"
  @code_verifier "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

  defmodule Callbacks do
    @moduledoc false
    @behaviour Boruta.Oauth.AuthorizeApplication
    @behaviour Boruta.Oauth.TokenApplication

    @impl Boruta.Oauth.AuthorizeApplication
    def preauthorize_success(_conn, success), do: success
    @impl Boruta.Oauth.AuthorizeApplication
    def preauthorize_error(_conn, error), do: error
    @impl Boruta.Oauth.AuthorizeApplication
    def authorize_success(_conn, response), do: response
    @impl Boruta.Oauth.AuthorizeApplication
    def authorize_error(_conn, error), do: error

    @impl Boruta.Oauth.TokenApplication
    def token_success(_conn, response), do: response
    @impl Boruta.Oauth.TokenApplication
    def token_error(_conn, error), do: error
  end

  @doc """
  Issues an access and a refresh token for the user through the player OAuth client (authorization code + PKCE).
  """
  @spec player_tokens(PremiereEcoute.Accounts.User.t()) :: %{access_token: String.t(), refresh_token: String.t()}
  def player_tokens(user), do: oauth_tokens(user, OauthClient.id(), "player", @redirect_uri)

  @doc """
  Issues an access and a refresh token for the user through any OAuth client (authorization code + PKCE).
  """
  @spec oauth_tokens(PremiereEcoute.Accounts.User.t(), String.t(), String.t(), String.t()) ::
          %{access_token: String.t(), refresh_token: String.t()}
  def oauth_tokens(user, client_id, scope, redirect_uri) do
    authorize_conn = %Plug.Conn{
      query_params: %{
        "response_type" => "code",
        "client_id" => client_id,
        "redirect_uri" => redirect_uri,
        "scope" => scope,
        "state" => "xyz",
        "code_challenge" => :crypto.hash(:sha256, @code_verifier) |> Base.url_encode64(padding: false),
        "code_challenge_method" => "S256"
      }
    }

    %AuthorizeResponse{code: code} =
      Boruta.Oauth.authorize(authorize_conn, %ResourceOwner{sub: to_string(user.id), username: user.email}, Callbacks)

    token_conn = %Plug.Conn{
      body_params: %{
        "grant_type" => "authorization_code",
        "code" => code,
        "redirect_uri" => redirect_uri,
        "client_id" => client_id,
        "code_verifier" => @code_verifier
      },
      query_params: %{}
    }

    %TokenResponse{access_token: access_token, refresh_token: refresh_token} = Boruta.Oauth.token(token_conn, Callbacks)
    %{access_token: access_token, refresh_token: refresh_token}
  end

  @doc """
  Refreshes the player's tokens with a refresh token, as the player does (the refresh token is rotated).
  """
  @spec refresh_player_tokens(String.t()) ::
          {:ok, %{access_token: String.t(), refresh_token: String.t()}} | {:error, Boruta.Oauth.Error.t()}
  def refresh_player_tokens(refresh_token) do
    conn = %Plug.Conn{
      body_params: %{"grant_type" => "refresh_token", "refresh_token" => refresh_token, "client_id" => OauthClient.id()},
      query_params: %{}
    }

    case Boruta.Oauth.token(conn, Callbacks) do
      %TokenResponse{access_token: access, refresh_token: refresh} -> {:ok, %{access_token: access, refresh_token: refresh}}
      %Boruta.Oauth.Error{} = error -> {:error, error}
    end
  end

  @doc """
  Makes an access token expire an hour ago, as if the player had been running for hours.

  Boruta keeps a token in a cache for as long as it lives and then reads the database, where the expiry is recorded: the cached copy is dropped so that the aged row is what is read.
  """
  @spec expire_access_token(String.t()) :: :ok
  def expire_access_token(access_token) do
    past = System.os_time(:second) - 3_600
    cached = Boruta.AccessTokensAdapter.get_by(value: access_token)
    PremiereEcoute.Repo.update_all(from(t in Token, where: t.value == ^access_token), set: [expires_at: past])
    if cached, do: TokenStore.invalidate(cached)
    :ok
  end
end
