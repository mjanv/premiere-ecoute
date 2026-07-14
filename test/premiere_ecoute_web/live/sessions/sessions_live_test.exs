defmodule PremiereEcouteWeb.Sessions.SessionsLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.ListeningSession

  describe "sessions list with a :clip session" do
    test "renders without error", %{conn: conn} do
      user = user_fixture(%{role: :streamer})
      {:ok, single} = single_fixture(%{provider_ids: %{spotify: "spotify_id", youtube: "yt_id"}}) |> Single.create()

      {:ok, _session} = ListeningSession.create(%{user_id: user.id, source: :clip, single_id: single.id})

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/sessions")

      assert html =~ single.name
      assert html =~ "Clip"
    end
  end
end
