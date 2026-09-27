defmodule PremiereEcouteWeb.Accounts.FollowsLiveTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "/users/follows" do
    test "renders the follows page instead of a user profile", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      {:ok, _view, html} = live(conn, ~p"/users/follows")

      assert html =~ "My Follows"
    end

    test "lists the streamers the user follows", %{conn: conn} do
      user = user_fixture()
      streamer = user_fixture(%{role: :streamer})
      {:ok, _} = PremiereEcoute.Accounts.follow(user, streamer)
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/users/follows")

      assert html =~ streamer.username
    end
  end
end
