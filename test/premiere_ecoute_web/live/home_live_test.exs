defmodule PremiereEcouteWeb.HomeLiveTest do
  use PremiereEcouteWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    PremiereEcouteCore.FeatureFlag.enable(:billboards)
    PremiereEcouteCore.FeatureFlag.enable(:listening_sessions)
    PremiereEcouteCore.FeatureFlag.enable(:follow_channels)
    PremiereEcouteCore.FeatureFlag.enable(:playlists)

    :ok
  end

  describe "home" do
    test "displays content for authenticated viewer", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/home")

      assert html =~ "Premiere Ecoute"
      assert html =~ "Welcome back"
    end

    test "displays content for authenticated streamer", %{conn: conn} do
      user = user_fixture()
      {:ok, streamer_user} = PremiereEcoute.Accounts.update_user_role(user, :streamer)
      conn = log_in_user(conn, streamer_user)

      {:ok, _lv, html} = live(conn, ~p"/home")

      # Basic content still visible
      assert html =~ "Premiere Ecoute"

      # Streamer action buttons
      assert html =~ "New Session"
      assert html =~ "My Sessions"
      assert html =~ "Retrospective"

      # Check button links
      assert html =~ "href=\"/discography/album/select\""
      assert html =~ "href=\"/sessions\""
      assert html =~ "href=\"/retrospective/history\""
    end
  end
end
