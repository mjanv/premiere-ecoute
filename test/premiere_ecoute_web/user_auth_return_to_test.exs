defmodule PremiereEcouteWeb.UserAuthReturnToTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias PremiereEcouteWeb.UserAuth

  defp conn_with_return_to(conn, path) do
    conn |> init_test_session(%{}) |> then(fn conn -> if path, do: put_session(conn, :user_return_to, path), else: conn end)
  end

  describe "put_default_return_to/2" do
    test "sets the default when nothing was stored", %{conn: conn} do
      conn = conn |> conn_with_return_to(nil) |> UserAuth.put_default_return_to("/")

      assert get_session(conn, :user_return_to) == "/"
    end

    test "keeps an OAuth authorize request, so a player that was sent to log in comes back to it", %{conn: conn} do
      authorize = "/oauth/authorize?response_type=code&client_id=6c1d8f0e&scope=player&state=abc"
      conn = conn |> conn_with_return_to(authorize) |> UserAuth.put_default_return_to("/")

      assert get_session(conn, :user_return_to) == authorize
    end

    test "replaces any other stored page with the default, as before", %{conn: conn} do
      conn = conn |> conn_with_return_to("/sessions/42") |> UserAuth.put_default_return_to("/")

      assert get_session(conn, :user_return_to) == "/"
    end

    test "does not take a path that only looks like the authorize page", %{conn: conn} do
      conn = conn |> conn_with_return_to("/oauth/authorized-apps") |> UserAuth.put_default_return_to("/")

      assert get_session(conn, :user_return_to) == "/"
    end
  end
end
