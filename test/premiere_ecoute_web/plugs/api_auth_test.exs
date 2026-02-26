defmodule PremiereEcouteWeb.Plugs.ApiAuthTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias PremiereEcoute.Accounts
  alias PremiereEcouteWeb.Plugs.ApiAuth

  describe "call/2 with a valid API token" do
    test "assigns current_scope and does not halt", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_api_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> ApiAuth.call([])

      refute conn.halted
      assert conn.assigns.current_scope.user.id == user.id
    end
  end

  describe "call/2 with a missing header" do
    test "halts with 401", %{conn: conn} do
      conn = ApiAuth.call(conn, [])

      assert conn.halted
      assert json_response(conn, 401) == %{"error" => "Missing or invalid Authorization header"}
    end
  end

  describe "call/2 with a malformed header" do
    test "halts with 401 when not Bearer scheme", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Basic dXNlcjpwYXNz")
        |> ApiAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "halts with 401 for a random string as token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not-a-valid-token")
        |> ApiAuth.call([])

      assert conn.halted
      assert json_response(conn, 401) == %{"error" => "Invalid or expired token"}
    end
  end

  describe "call/2 with a session token" do
    test "halts with 401 — session tokens are not accepted", %{conn: conn} do
      user = user_fixture()
      raw_token = Accounts.generate_user_session_token(user)
      bearer = Base.url_encode64(raw_token, padding: false)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{bearer}")
        |> ApiAuth.call([])

      assert conn.halted
      assert json_response(conn, 401) == %{"error" => "Invalid or expired token"}
    end
  end

  describe "call/2 with a deleted API token" do
    test "halts with 401", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_api_token(user)
      Accounts.delete_user_api_tokens(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> ApiAuth.call([])

      assert conn.halted
      assert json_response(conn, 401) == %{"error" => "Invalid or expired token"}
    end
  end
end
