defmodule PremiereEcouteWeb.HomepageLiveTest do
  use PremiereEcouteWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "homepage" do
    test "displays the homepage", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      # Titles
      assert html =~ "Premiere Ecoute"
      assert html =~ "Share your music taste with the world"
      assert html =~ "Create listening sessions"

      # Navigation links
      assert html =~ "Connect with Twitch"
      assert html =~ "href=\"/auth/twitch\""

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

      # Test main CTA button (homepage Connect with Twitch - the larger button)
      assert lv
             |> element("a[href='/auth/twitch'].bg-purple-600", "Connect with Twitch")
             |> render_click()
             |> follow_redirect(conn, ~p"/auth/twitch")
    end

    test "displays content for authenticated viewer", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/")

      # Basic content still visible
      assert html =~ "Premiere Ecoute"

      # Viewer-specific content
      assert html =~ "Welcome back"
      assert html =~ "Explore listening sessions and join the community discussions."

      # Features preview not shown
      refute html =~ "Album Discovery"
      refute html =~ "Community Rating"
      refute html =~ "Live Sessions"

      # No streamer action buttons
      refute html =~ "Start New Session"
      refute html =~ "My Sessions"
      refute html =~ "My Retrospective"
    end

    test "displays content for authenticated streamer", %{conn: conn} do
      user = user_fixture()
      {:ok, streamer_user} = PremiereEcoute.Accounts.update_user_role(user, :streamer)
      conn = log_in_user(conn, streamer_user)

      {:ok, _lv, html} = live(conn, ~p"/")

      # Basic content still visible
      assert html =~ "Premiere Ecoute"

      # Streamer action buttons
      assert html =~ "Start New Session"
      assert html =~ "My Sessions"
      assert html =~ "My Retrospective"

      # Check button links
      assert html =~ "href=\"/sessions/discography/album/select\""
      assert html =~ "href=\"/sessions\""
      assert html =~ "href=\"/sessions/wrapped/retrospective\""
    end
  end
end
