defmodule PremiereEcouteWeb.Accounts.AccountFeaturesLiveTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "clip overlay URL" do
    test "shows the clip overlay URL when selected", %{conn: conn} do
      user = user_fixture(%{role: :streamer})
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/users/account/features")

      html =
        view
        |> element("form[phx-change='change_overlay_score_type']")
        |> render_change(%{"score_type" => "clip"})

      assert html =~ "/sessions/overlay/#{user.username}/clip"
    end
  end
end
