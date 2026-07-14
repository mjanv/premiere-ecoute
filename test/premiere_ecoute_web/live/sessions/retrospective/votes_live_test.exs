defmodule PremiereEcouteWeb.Sessions.Retrospective.VotesLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Vote

  describe "clip source filter" do
    test "renders votes on clip sessions without error", %{conn: conn} do
      streamer = user_fixture(%{role: :streamer})
      viewer = user_fixture(%{twitch: %{user_id: "viewer_clip_1"}})

      {:ok, single} = single_fixture(%{provider_ids: %{spotify: "spotify_id", youtube: "yt_id"}}) |> Single.create()

      {:ok, session} = ListeningSession.create(%{user_id: streamer.id, source: :clip, single_id: single.id})
      {:ok, session} = ListeningSession.start(session)

      {:ok, _vote} =
        Vote.create(%Vote{
          viewer_id: "viewer_clip_1",
          session_id: session.id,
          track_id: single.id,
          value: "9",
          is_streamer: false
        })

      conn = log_in_user(conn, viewer)
      {:ok, view, _html} = live(conn, ~p"/sessions/retrospective/votes?source=clip")

      html = render_async(view)

      assert html =~ single.name
    end
  end
end
