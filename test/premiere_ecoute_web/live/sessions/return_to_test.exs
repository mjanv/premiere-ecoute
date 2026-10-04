defmodule PremiereEcouteWeb.Sessions.ReturnToTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report

  setup %{conn: conn} do
    user = user_fixture(%{role: :streamer})
    {:ok, single} = single_fixture(%{provider_ids: %{spotify: "spotify_id"}}) |> Single.create()
    {:ok, session} = ListeningSession.create(%{user_id: user.id, source: :track, single_id: single.id})
    {:ok, session} = ListeningSession.start(session)
    {:ok, session} = ListeningSession.stop(session)
    {:ok, _report} = Report.generate(session)

    %{conn: log_in_user(conn, user), user: user, session: session}
  end

  test "history cards carry the current filters in return_to", %{conn: conn, user: user, session: session} do
    {:ok, view, _html} = live(conn, ~p"/sessions/retrospective?source=track&sort=score")
    html = render_async(view)

    expected =
      "/sessions/#{user.username}/#{session.share_token}?return_to=" <>
        URI.encode_www_form("/sessions/retrospective?source=track&sort=score")

    assert html =~ String.replace(expected, "&", "&amp;")
  end

  test "back link returns to the given page", %{conn: conn, user: user, session: session} do
    return_to = "/sessions/retrospective?month=9&period=month&source=track&year=2026"

    {:ok, _view, html} =
      live(conn, ~p"/sessions/#{user.username}/#{session.share_token}?#{[return_to: return_to]}")

    assert html =~ ~s(href="#{String.replace(return_to, "&", "&amp;")}")
  end

  test "back link ignores an external return_to", %{conn: conn, user: user, session: session} do
    {:ok, view, _html} =
      live(conn, ~p"/sessions/#{user.username}/#{session.share_token}?#{[return_to: "//evil.com"]}")

    assert has_element?(view, ~s(#back-link[href="/sessions/retrospective"]))
  end

  test "back link defaults to the history page", %{conn: conn, user: user, session: session} do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{user.username}/#{session.share_token}")

    assert has_element?(view, ~s(#back-link[href="/sessions/retrospective"]))
  end

  test "back link returns to my sessions, which is matched exactly", %{conn: conn, user: user, session: session} do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{user.username}/#{session.share_token}?#{[return_to: "/sessions"]}")
    assert has_element?(view, ~s(#back-link[href="/sessions"]), "Back to my sessions")

    {:ok, view, _html} =
      live(conn, ~p"/sessions/#{user.username}/#{session.share_token}?#{[return_to: "/sessions/new"]}")

    assert has_element?(view, ~s(#back-link[href="/sessions/retrospective"]))
  end

  test "back link is labelled after the origin page", %{conn: conn, user: user, session: session} do
    {:ok, view, _html} =
      live(conn, ~p"/sessions/#{user.username}/#{session.share_token}?#{[return_to: "/home"]}")

    assert has_element?(view, ~s(#back-link[href="/home"]), "Back to home")
  end
end
