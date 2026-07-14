defmodule PremiereEcouteWeb.Sessions.ClipPublicSessionLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.ListeningSession

  describe "public session page for a :clip session" do
    test "renders without error", %{conn: conn} do
      user = user_fixture(%{role: :streamer})
      {:ok, single} = single_fixture(%{provider_ids: %{spotify: "spotify_id", youtube: "yt_id"}}) |> Single.create()

      {:ok, session} = ListeningSession.create(%{user_id: user.id, source: :clip, single_id: single.id})

      viewer = user_fixture()
      conn = log_in_user(conn, viewer)

      {:ok, _view, html} = live(conn, ~p"/sessions/#{user.username}/#{session.share_token}")

      assert html =~ single.name
    end
  end
end
