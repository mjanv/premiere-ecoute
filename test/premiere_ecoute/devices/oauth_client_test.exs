defmodule PremiereEcoute.Devices.OauthClientTest do
  use PremiereEcoute.DataCase, async: true

  import PremiereEcoute.AccountsFixtures

  alias Boruta.Ecto.Admin
  alias Boruta.Oauth.Authorization.AccessToken
  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Oauth.TokenResponse
  alias PremiereEcoute.Devices.OauthClient
  alias PremiereEcoute.Devices.OauthClientTest.Callbacks

  @redirect_uri "http://127.0.0.1:53682/cb"
  @code_verifier "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

  describe "player client" do
    test "issues a player-scoped token through authorization code + PKCE" do
      user = user_fixture()

      assert %AuthorizeResponse{code: code} = authorize(OauthClient.id(), user, "player", @redirect_uri)

      assert %TokenResponse{access_token: access_token, refresh_token: refresh_token} =
               exchange_code(OauthClient.id(), code, @redirect_uri)

      assert is_binary(access_token)
      assert is_binary(refresh_token)
      assert {:ok, %{scope: "player", sub: sub}} = AccessToken.authorize(value: access_token)
      assert sub == to_string(user.id)
    end

    test "only accepts the loopback callback as redirect URI" do
      user = user_fixture()

      for redirect_uri <- ["http://127.0.0.1:53682/cb", "http://127.0.0.1:8080/cb"] do
        assert %AuthorizeResponse{} = authorize(OauthClient.id(), user, "player", redirect_uri)
      end

      for redirect_uri <- [
            "http://localhost:53682/cb",
            "https://127.0.0.1:53682/cb",
            "http://127.0.0.1.evil.com:53682/cb",
            "http://127.0.0.1:53682/other",
            "http://127.0.0.1:1/cb",
            "http://evil.com/cb"
          ] do
        assert %Boruta.Oauth.Error{error: :invalid_client} =
                 authorize(OauthClient.id(), user, "player", redirect_uri)
      end
    end

    test "scope player is refused to clients that were not granted it" do
      user = user_fixture()

      {:ok, client} =
        Admin.create_client(%{
          name: "dynamically registered",
          redirect_uris: ["https://example.com/callback"],
          supported_grant_types: ["authorization_code"],
          pkce: true
        })

      assert %Boruta.Oauth.Error{error: :invalid_scope} =
               authorize(client.id, user, "player", "https://example.com/callback")
    end

    test "refreshes an access token without a client secret, rotating the refresh token" do
      user = user_fixture()
      %AuthorizeResponse{code: code} = authorize(OauthClient.id(), user, "player", @redirect_uri)
      %TokenResponse{refresh_token: refresh_token} = exchange_code(OauthClient.id(), code, @redirect_uri)

      assert %TokenResponse{access_token: new_access_token, refresh_token: new_refresh_token} =
               refresh(OauthClient.id(), refresh_token)

      assert new_refresh_token != refresh_token
      assert {:ok, %{scope: "player"}} = AccessToken.authorize(value: new_access_token)
      assert %Boruta.Oauth.Error{} = refresh(OauthClient.id(), refresh_token)
    end

    test "revokes its refresh token without a client secret" do
      user = user_fixture()
      %AuthorizeResponse{code: code} = authorize(OauthClient.id(), user, "player", @redirect_uri)
      %TokenResponse{refresh_token: refresh_token} = exchange_code(OauthClient.id(), code, @redirect_uri)

      assert :ok = revoke(OauthClient.id(), refresh_token, "refresh_token")
      assert %Boruta.Oauth.Error{} = refresh(OauthClient.id(), refresh_token)
    end

    test "issues access tokens for one hour and refresh tokens for thirty days" do
      user = user_fixture()
      %AuthorizeResponse{code: code} = authorize(OauthClient.id(), user, "player", @redirect_uri)

      assert %TokenResponse{expires_in: expires_in} = exchange_code(OauthClient.id(), code, @redirect_uri)
      assert expires_in in 3_598..3_600
      assert %Boruta.Oauth.Client{refresh_token_ttl: 2_592_000} = Boruta.ClientsAdapter.get_client(OauthClient.id())
    end
  end

  describe "ensure!/0" do
    test "returns the existing client without creating another one" do
      count = fn -> PremiereEcoute.Repo.aggregate(Boruta.Ecto.Client, :count) end
      before = count.()

      assert %Boruta.Ecto.Client{id: id} = OauthClient.ensure!()
      assert id == OauthClient.id()
      assert count.() == before
    end
  end

  defp authorize(client_id, user, scope, redirect_uri) do
    conn = %Plug.Conn{
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

    Boruta.Oauth.authorize(conn, %ResourceOwner{sub: to_string(user.id), username: user.email}, Callbacks)
  end

  defp exchange_code(client_id, code, redirect_uri) do
    conn = %Plug.Conn{
      body_params: %{
        "grant_type" => "authorization_code",
        "code" => code,
        "redirect_uri" => redirect_uri,
        "client_id" => client_id,
        "code_verifier" => @code_verifier
      },
      query_params: %{}
    }

    Boruta.Oauth.token(conn, Callbacks)
  end

  defp refresh(client_id, refresh_token) do
    conn = %Plug.Conn{
      body_params: %{"grant_type" => "refresh_token", "refresh_token" => refresh_token, "client_id" => client_id},
      query_params: %{}
    }

    Boruta.Oauth.token(conn, Callbacks)
  end

  defp revoke(client_id, token, hint) do
    conn = %Plug.Conn{
      body_params: %{"client_id" => client_id, "token" => token, "token_type_hint" => hint},
      query_params: %{}
    }

    Boruta.Oauth.revoke(conn, Callbacks)
  end

  defmodule Callbacks do
    @moduledoc false
    @behaviour Boruta.Oauth.AuthorizeApplication
    @behaviour Boruta.Oauth.TokenApplication
    @behaviour Boruta.Oauth.RevokeApplication

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

    @impl Boruta.Oauth.RevokeApplication
    def revoke_success(_conn), do: :ok
    @impl Boruta.Oauth.RevokeApplication
    def revoke_error(_conn, error), do: error
  end
end
