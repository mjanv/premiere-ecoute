defmodule PremiereEcouteWeb.Api.StatusControllerTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias PremiereEcoute.Accounts

  describe "GET /api/status" do
    test "returns user info for a valid API token", %{conn: conn} do
      user = user_fixture()
      token = Accounts.generate_user_api_token(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/status")

      assert %{
               "status" => "ok",
               "user" => %{
                 "id" => user_id,
                 "username" => username,
                 "role" => role
               }
             } = json_response(conn, 200)

      assert user_id == user.id
      assert username == user.username
      assert role == to_string(user.role)
    end

    test "returns 401 without authorization header", %{conn: conn} do
      conn = get(conn, ~p"/api/status")

      assert json_response(conn, 401) == %{"error" => "Missing or invalid Authorization header"}
    end

    test "returns 401 with an invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid")
        |> get(~p"/api/status")

      assert json_response(conn, 401) == %{"error" => "Invalid or expired token"}
    end
  end
end
