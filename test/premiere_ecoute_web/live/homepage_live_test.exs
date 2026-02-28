defmodule PremiereEcouteWeb.HomepageLiveTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "homepage" do
    test "displays the homepage", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      # Titles
      assert html =~ "Premiere Ecoute"
      assert html =~ "Share and discover music"

      # Navigation links
      assert html =~ "Connect with Twitch"

      # Feature previews
      assert html =~ "Listening Sessions"
      assert html =~ "Retrospective"
      assert html =~ "Billboards"
      assert html =~ "Host album release listening sessions"
      assert html =~ "Global retros for streamers"
      assert html =~ "Create your billboard playlist "
    end

    test "navigation links work correctly", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      # Test main CTA button (homepage Connect with Twitch - the larger button)
      assert lv
             |> element("a[href='/'].text-purple-300", "Connect with Twitch")
             |> render_click()
             |> follow_redirect(conn, ~p"/")
    end
  end
end
