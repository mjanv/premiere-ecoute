defmodule PremiereEcouteWeb.Sessions.Retrospective.StreamerLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report

  describe "clip source filter" do
    test "renders clip sessions without error", %{conn: conn} do
      user = user_fixture(%{role: :streamer})
      {:ok, single} = single_fixture(%{provider_ids: %{spotify: "spotify_id", youtube: "yt_id"}}) |> Single.create()

      {:ok, session} = ListeningSession.create(%{user_id: user.id, source: :clip, single_id: single.id})
      {:ok, session} = ListeningSession.start(session)
      {:ok, session} = ListeningSession.stop(session)
      {:ok, _report} = Report.generate(session)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/retrospective?source=clip")

      html = render_async(view)

      assert html =~ single.name
    end
  end
end
