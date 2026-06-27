defmodule PremiereEcouteWeb.Mcp.ServerTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.AccountsFixtures

  alias Boruta.Ecto.Admin
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Oauth.TokenResponse
  alias PremiereEcoute.Accounts.User.Token
  alias PremiereEcouteWeb.Mcp.Server

  describe "authenticate/2 via x-api-key" do
    test "authenticates the user for a valid API token" do
      user = user_fixture()
      api_key = Token.generate_user_api_token(user)

      assert {:ok, authenticated} = Server.authenticate([api_key], nil)
      assert authenticated.id == user.id
    end

    test "falls through to bearer token check for an invalid API token" do
      assert Server.authenticate(["not-a-valid-token"], nil) == :error
    end

    test "rejects when no headers are present at all" do
      assert Server.authenticate(nil, nil) == :error
    end
  end

  describe "authenticate/2 via Authorization Bearer header" do
    test "rejects a missing authorization header" do
      assert Server.authenticate(nil, nil) == :error
    end

    test "rejects an authorization header without the Bearer scheme" do
      assert Server.authenticate(nil, ["Basic dXNlcjpwYXNz"]) == :error
    end

    test "rejects a malformed bearer token" do
      assert Server.authenticate(nil, ["Bearer not-a-real-oauth-token"]) == :error
    end

    test "rejects multiple authorization headers" do
      assert Server.authenticate(nil, ["Bearer one", "Bearer two"]) == :error
    end

    test "authenticates the user for a real Boruta access token issued via authorization_code + PKCE" do
      user = user_fixture()

      {:ok, client} =
        Admin.create_client(%{
          name: "claude.ai",
          redirect_uris: ["https://claude.ai/api/mcp/auth_callback"],
          supported_grant_types: ["authorization_code", "refresh_token"],
          pkce: true
        })

      code_verifier = "AaypQFt5gKjNdyiPjJ6AQ1UDbPJtbym3Oa6OpwiRV0g"
      code_challenge = :crypto.hash(:sha256, code_verifier) |> Base.url_encode64(padding: false)

      resource_owner = %ResourceOwner{sub: to_string(user.id), username: user.email}

      authorize_conn = %Plug.Conn{
        query_params: %{
          "response_type" => "code",
          "client_id" => client.id,
          "redirect_uri" => "https://claude.ai/api/mcp/auth_callback",
          "scope" => "mcp",
          "state" => "xyz",
          "code_challenge" => code_challenge,
          "code_challenge_method" => "S256"
        }
      }

      assert %AuthorizeResponse{code: code} =
               Boruta.Oauth.authorize(authorize_conn, resource_owner, AuthorizeCallback)

      token_conn = %Plug.Conn{
        body_params: %{
          "grant_type" => "authorization_code",
          "code" => code,
          "redirect_uri" => "https://claude.ai/api/mcp/auth_callback",
          "client_id" => client.id,
          "code_verifier" => code_verifier
        },
        query_params: %{}
      }

      assert %TokenResponse{access_token: access_token} = Boruta.Oauth.token(token_conn, TokenCallback)

      assert {:ok, authenticated} = Server.authenticate(nil, ["Bearer #{access_token}"])
      assert authenticated.id == user.id
    end
  end
end

defmodule AuthorizeCallback do
  @moduledoc false
  @behaviour Boruta.Oauth.AuthorizeApplication

  alias Boruta.Oauth.AuthorizationSuccess
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Error

  @impl Boruta.Oauth.AuthorizeApplication
  def preauthorize_success(_conn, %AuthorizationSuccess{} = success), do: success

  @impl Boruta.Oauth.AuthorizeApplication
  def preauthorize_error(_conn, %Error{} = error), do: error

  @impl Boruta.Oauth.AuthorizeApplication
  def authorize_success(_conn, %AuthorizeResponse{} = response), do: response

  @impl Boruta.Oauth.AuthorizeApplication
  def authorize_error(_conn, %Error{} = error), do: error
end

defmodule TokenCallback do
  @moduledoc false
  @behaviour Boruta.Oauth.TokenApplication

  alias Boruta.Oauth.Error
  alias Boruta.Oauth.TokenResponse

  @impl Boruta.Oauth.TokenApplication
  def token_success(_conn, %TokenResponse{} = response), do: response

  @impl Boruta.Oauth.TokenApplication
  def token_error(_conn, %Error{} = error), do: error
end
