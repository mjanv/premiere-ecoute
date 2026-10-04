defmodule PremiereEcouteWeb.Accounts.TermsAcceptanceLiveTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "mount/3" do
    test "redirects home when there is no pending Twitch authentication", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/", flash: flash}}} = live(conn, ~p"/users/terms-acceptance")
      assert flash["error"] == "Authentication session expired"
    end

    test "redirects home when the pending Twitch authentication is nil", %{conn: conn} do
      conn = init_test_session(conn, %{"pending_twitch_auth" => nil})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/users/terms-acceptance")
    end

    test "renders the legal documents when a Twitch authentication is pending", %{conn: conn} do
      conn = init_test_session(conn, %{"pending_twitch_auth" => %{auth_data: %{}, timestamp: System.system_time(:second)}})

      assert {:ok, _view, _html} = live(conn, ~p"/users/terms-acceptance")
    end
  end
end
