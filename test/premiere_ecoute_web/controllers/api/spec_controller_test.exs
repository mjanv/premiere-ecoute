defmodule PremiereEcouteWeb.Api.SpecControllerTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias PremiereEcoute.Accounts

  describe "GET /api/openapi unauthenticated" do
    test "returns 200 with no paths", %{conn: conn} do
      conn = get(conn, ~p"/api/openapi")

      assert %{"paths" => paths} = json_response(conn, 200)
      assert paths == %{}
    end
  end

  describe "GET /api/openapi as a streamer" do
    setup do
      user = user_fixture(%{role: :streamer})
      token = Accounts.generate_user_api_token(user)
      {:ok, token: token}
    end

    test "includes streamer-only endpoints", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/openapi")

      assert %{"paths" => paths} = json_response(conn, 200)
      path_keys = Map.keys(paths)

      assert Enum.any?(path_keys, &String.contains?(&1, "/api/session"))
      assert Enum.any?(path_keys, &String.contains?(&1, "/api/collection"))
    end

    test "includes streamer+viewer shared endpoints", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/openapi")

      assert %{"paths" => paths} = json_response(conn, 200)
      path_keys = Map.keys(paths)

      assert Enum.any?(path_keys, &String.contains?(&1, "/api/wantlist"))
      assert Enum.any?(path_keys, &String.contains?(&1, "/api/user"))
    end
  end

  describe "GET /api/openapi as a viewer" do
    setup do
      user = user_fixture(%{role: :viewer})
      token = Accounts.generate_user_api_token(user)
      {:ok, token: token}
    end

    test "excludes streamer-only endpoints", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/openapi")

      assert %{"paths" => paths} = json_response(conn, 200)

      # Session dashboard (start/stop/next/previous) and collection dashboard are streamer-only
      refute Map.has_key?(paths, "/api/session")
      refute Map.has_key?(paths, "/api/collection")
    end

    test "includes streamer+viewer shared endpoints", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/openapi")

      assert %{"paths" => paths} = json_response(conn, 200)
      path_keys = Map.keys(paths)

      assert Enum.any?(path_keys, &String.contains?(&1, "/api/wantlist"))
      assert Enum.any?(path_keys, &String.contains?(&1, "/api/user"))
    end
  end
end
