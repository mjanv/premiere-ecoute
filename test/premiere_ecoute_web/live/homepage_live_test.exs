defmodule PremiereEcouteWeb.HomepageLiveTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Phoenix.HTML, only: [html_escape: 1, safe_to_string: 1]
  import PremiereEcoute.Gettext

  describe "homepage" do
    test "displays the homepage", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/")

      # Titles
      assert html =~ "Premiere Ecoute"

      assert html =~
               gettext(
                 "Share and discover music with our audience. Start listening sessions, rate albums, and share playlists to unveil new gems."
               )

      # Twitch login buttons — html_escape handles the apostrophe in "I'm a Twitch"
      assert html =~ gettext("I'm a Twitch") |> html_escape() |> safe_to_string()
      assert html =~ gettext("streamer")
      assert html =~ gettext("viewer")

      # Feature previews
      assert html =~ gettext("Listening Sessions")
      assert html =~ gettext("Retrospective")
      assert html =~ gettext("Billboards")
      assert html =~ gettext("Host album release listening sessions and let your chat votes for every track")
      assert html =~ gettext("Global retros for streamers and personal recaps for every viewer to review your year")
      assert html =~ gettext("Create your billboard playlist by merging hundred of community playlists together")
    end

    test "displays Twitch login buttons with correct links", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/")

      assert lv |> element("a[href='#{~p"/auth/twitch?role=streamer"}']") |> has_element?()
      assert lv |> element("a[href='#{~p"/auth/twitch?role=viewer"}']") |> has_element?()
    end
  end
end
