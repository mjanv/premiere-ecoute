defmodule PremiereEcouteWeb.Sessions.Retrospective.StreamerLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Vote

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

  describe "track source ranked by score" do
    test "sort=score orders tracks by viewer_score descending", %{conn: conn} do
      user = user_fixture(%{role: :streamer})
      viewer = user_fixture(%{twitch: %{user_id: "viewer1"}})

      {:ok, low_single} =
        single_fixture(%{provider_ids: %{spotify: "spotify_low"}, name: "Low Track"}) |> Single.create()

      {:ok, low_session} = ListeningSession.create(%{user_id: user.id, source: :track, single_id: low_single.id})
      {:ok, low_session} = ListeningSession.start(low_session)

      {:ok, _} =
        Vote.create(%Vote{
          viewer_id: viewer.twitch.user_id,
          session_id: low_session.id,
          track_id: low_single.id,
          value: "2",
          is_streamer: false
        })

      {:ok, low_session} = ListeningSession.stop(low_session)
      {:ok, _report} = Report.generate(low_session)

      {:ok, high_single} =
        single_fixture(%{provider_ids: %{spotify: "spotify_high"}, name: "High Track"}) |> Single.create()

      {:ok, high_session} = ListeningSession.create(%{user_id: user.id, source: :track, single_id: high_single.id})
      {:ok, high_session} = ListeningSession.start(high_session)

      {:ok, _} =
        Vote.create(%Vote{
          viewer_id: viewer.twitch.user_id,
          session_id: high_session.id,
          track_id: high_single.id,
          value: "9",
          is_streamer: false
        })

      {:ok, high_session} = ListeningSession.stop(high_session)
      {:ok, _report} = Report.generate(high_session)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/sessions/retrospective?source=track&sort=score")

      html = render_async(view)

      assert String.contains?(html, "High Track")
      assert String.contains?(html, "Low Track")

      high_index = :binary.match(html, "High Track") |> elem(0)
      low_index = :binary.match(html, "Low Track") |> elem(0)

      assert high_index < low_index
    end
  end
end
