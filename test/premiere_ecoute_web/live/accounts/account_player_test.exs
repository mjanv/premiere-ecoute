defmodule PremiereEcouteWeb.Accounts.AccountPlayerTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PremiereEcoute.PlayerFixtures

  alias Boruta.Oauth.Authorization.AccessToken
  alias PremiereEcoute.Devices

  describe "desktop player" do
    test "is hidden when the user never connected a player", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      {:ok, view, _html} = live(conn, ~p"/users/account")

      refute has_element?(view, "#desktop-player")
    end

    test "can be disconnected by the user", %{conn: conn} do
      user = user_fixture()
      %{access_token: access_token} = player_tokens(user)
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/users/account")
      assert has_element?(view, "#desktop-player")

      view |> element("#desktop-player button", "Disconnect") |> render_click()

      refute has_element?(view, "#desktop-player")
      refute Devices.player_enrolled?(user)
      assert {:error, _} = AccessToken.authorize(value: access_token)
    end
  end
end
