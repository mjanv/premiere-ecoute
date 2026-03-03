defmodule PremiereEcouteWeb.Api.UserProfileControllerTest do
  use PremiereEcouteWeb.ApiCase, async: true

  describe "GET /api/profile" do
    test "returns the user profile with default values", %{conn: conn} do
      user = user_fixture()

      conn = conn |> auth(user) |> get(~p"/api/profile")

      assert %{
               "color_scheme" => "system",
               "language" => "en",
               "timezone" => "UTC",
               "widget_settings" => %{
                 "color_primary" => "#5b21b6",
                 "color_secondary" => "#be123c"
               },
               "radio_settings" => %{
                 "enabled" => false,
                 "retention_days" => 7,
                 "visibility" => "public"
               }
             } = response(conn, 200, op(UserProfileController, :show))
    end

    test "returns the user profile with custom values", %{conn: conn} do
      user =
        user_fixture(%{
          profile: %{
            color_scheme: :dark,
            language: :fr,
            timezone: "Europe/Paris"
          }
        })

      conn = conn |> auth(user) |> get(~p"/api/profile")

      assert %{
               "color_scheme" => "dark",
               "language" => "fr",
               "timezone" => "Europe/Paris"
             } = response(conn, 200, op(UserProfileController, :show))
    end

    test "returns 401 without authorization header", %{conn: conn} do
      conn = get(conn, ~p"/api/profile")

      assert json_response(conn, 401) == %{"error" => "Missing or invalid Authorization header"}
    end
  end

  describe "PATCH /api/profile" do
    test "updates top-level fields", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> auth(user)
        |> patch(~p"/api/profile", %{color_scheme: "dark", language: "fr"})

      assert %{"color_scheme" => "dark", "language" => "fr", "timezone" => "UTC"} =
               response(conn, 200, op(UserProfileController, :update))
    end

    test "partial update only changes sent fields", %{conn: conn} do
      user = user_fixture(%{profile: %{color_scheme: :light, language: :it, timezone: "Europe/Rome"}})

      conn =
        conn
        |> auth(user)
        |> patch(~p"/api/profile", %{color_scheme: "dark"})

      assert %{
               "color_scheme" => "dark",
               "language" => "it",
               "timezone" => "Europe/Rome"
             } = response(conn, 200, op(UserProfileController, :update))
    end

    test "updates widget_settings", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> auth(user)
        |> patch(~p"/api/profile", %{widget_settings: %{color_primary: "#ff0000"}})

      assert %{
               "widget_settings" => %{
                 "color_primary" => "#ff0000",
                 "color_secondary" => "#be123c"
               }
             } = response(conn, 200, op(UserProfileController, :update))
    end

    test "updates radio_settings", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> auth(user)
        |> patch(~p"/api/profile", %{radio_settings: %{enabled: true, retention_days: 14}})

      assert %{
               "radio_settings" => %{
                 "enabled" => true,
                 "retention_days" => 14,
                 "visibility" => "public"
               }
             } = response(conn, 200, op(UserProfileController, :update))
    end

    test "returns 422 on invalid color_scheme", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> auth(user)
        |> patch(~p"/api/profile", %{color_scheme: "neon"})

      assert %{"errors" => %{"color_scheme" => _}} = json_response(conn, 422)
    end

    test "returns 422 on invalid hex color in widget_settings", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> auth(user)
        |> patch(~p"/api/profile", %{widget_settings: %{color_primary: "red"}})

      assert %{"errors" => %{"widget_settings" => %{"color_primary" => _}}} =
               json_response(conn, 422)
    end

    test "returns 422 on invalid timezone", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> auth(user)
        |> patch(~p"/api/profile", %{timezone: "Not/ATimezone"})

      assert %{"errors" => %{"timezone" => _}} = json_response(conn, 422)
    end

    test "returns 401 without authorization header", %{conn: conn} do
      conn = patch(conn, ~p"/api/profile", %{})

      assert json_response(conn, 401) == %{"error" => "Missing or invalid Authorization header"}
    end
  end
end
