defmodule PremiereEcouteWeb.HomepageLiveTest do
  use PremiereEcouteWeb.ConnCase

  import Phoenix.LiveViewTest

  # AIDEV-NOTE: Tests homepage LiveView functionality - content display, navigation, and link behavior

  describe "homepage" do
    test "displays the homepage", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      # Titles
      assert html =~ "Premiere Ecoute"
      assert html =~ "Share your music taste with the world"
      assert html =~ "Create listening sessions"

      # Navigation links
      assert html =~ "View All Sessions"
      assert html =~ "Account"
      assert html =~ "Connect with Twitch"
      assert html =~ "href=\"/auth/twitch\""

      # Action buttons
      assert html =~ "Start New Session"
      assert html =~ "Browse Sessions"

      # Feature previews
      assert html =~ "Album Discovery"
      assert html =~ "Community Rating"
      assert html =~ "Live Sessions"
      assert html =~ "Search and explore albums from Spotify"
      assert html =~ "Rate tracks together and see what the community thinks"
      assert html =~ "Host real-time listening parties with live voting"
    end

    test "navigation links work correctly", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      # Test sessions link
      assert lv
             |> element("a[href='/sessions']", "View All Sessions")
             |> render_click()
             |> follow_redirect(conn, ~p"/sessions")

      # Test account link
      {:ok, lv, _html} = live(conn, ~p"/")

      assert lv
             |> element("a[href='/account']", "Account")
             |> render_click()
             |> follow_redirect(conn, ~p"/account")

      # Test start new session link
      {:ok, lv, _html} = live(conn, ~p"/")

      assert lv
             |> element("a[href='/sessions/discography/album/select']", "Start New Session")
             |> render_click()
             |> follow_redirect(conn, ~p"/sessions/discography/album/select")
    end
  end
end
