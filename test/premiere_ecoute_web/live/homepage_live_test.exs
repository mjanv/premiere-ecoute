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
             |> element("a[href='/auth/twitch'].text-purple-300", "Connect with Twitch")
             |> render_click()
             |> follow_redirect(conn, ~p"/auth/twitch")
    end
  end
end
