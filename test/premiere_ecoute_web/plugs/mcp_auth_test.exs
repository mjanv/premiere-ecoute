defmodule PremiereEcouteWeb.Plugs.McpAuthTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import PremiereEcoute.AccountsFixtures

  alias PremiereEcoute.Accounts.User.Token
  alias PremiereEcouteWeb.Plugs.McpAuth

  describe "call/2 with a valid x-api-key" do
    test "does not halt", %{conn: conn} do
      user = user_fixture()
      api_key = Token.generate_user_api_token(user)

      conn =
        conn
        |> put_req_header("x-api-key", api_key)
        |> McpAuth.call([])

      refute conn.halted
    end
  end

  describe "call/2 with no credentials" do
    test "halts with 401 and a WWW-Authenticate header pointing at the protected-resource metadata", %{conn: conn} do
      conn = McpAuth.call(conn, [])

      assert conn.halted
      assert json_response(conn, 401) == %{"error" => "unauthorized"}

      issuer = Boruta.Config.issuer()
      assert [www_authenticate] = get_resp_header(conn, "www-authenticate")
      assert www_authenticate == "Bearer resource_metadata=\"#{issuer}/.well-known/oauth-protected-resource\""
    end
  end

  describe "call/2 with an invalid x-api-key" do
    test "halts with 401", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-api-key", "not-a-valid-token")
        |> McpAuth.call([])

      assert conn.halted
      assert json_response(conn, 401) == %{"error" => "unauthorized"}
    end
  end

  describe "call/2 with an invalid bearer token" do
    test "halts with 401", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not-a-real-oauth-token")
        |> McpAuth.call([])

      assert conn.halted
      assert json_response(conn, 401) == %{"error" => "unauthorized"}
    end
  end
end
