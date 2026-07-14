defmodule PremiereEcouteWeb.Sessions.YoutubeControlPanelTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PremiereEcoute.Discography.SingleFixtures

  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Sessions.ListeningSession

  setup %{conn: conn} do
    user =
      user_fixture(%{
        role: :streamer,
        twitch: %{user_id: "1234"},
        spotify: %{user_id: "spotify_user_123", username: "spotifyuser"}
      })

    {:ok, single} = single_fixture(%{provider_ids: %{spotify: "spotify_id", youtube: "yt_id"}}) |> Single.create()
    {:ok, session} = ListeningSession.create(%{user_id: user.id, source: :clip, single_id: single.id})
    {:ok, session} = ListeningSession.start(session)

    conn = log_in_user(conn, user)
    {:ok, user: user, session: session, conn: conn}
  end

  describe "clip control panel on the dashboard" do
    test "play/pause/volume broadcast clip_command over PubSub", %{conn: conn, session: session} do
      PremiereEcoute.PubSub.subscribe("session:#{session.id}")

      {:ok, view, _html} = live(conn, ~p"/sessions/#{session.share_token}/dashboard")

      view |> element("[phx-click='clip_play']") |> render_click()
      assert_receive {:clip_command, %{command: "play"}}

      view |> element("[phx-click='clip_pause']") |> render_click()
      assert_receive {:clip_command, %{command: "pause"}}

      view |> element("#clip-volume-bar") |> render_hook("clip_volume", %{"volume" => 42})
      assert_receive {:clip_command, %{command: "volume", value: 42}}
    end

    test "displays progress once the overlay reports it", %{conn: conn, session: session} do
      {:ok, view, html} = live(conn, ~p"/sessions/#{session.share_token}/dashboard")

      refute html =~ "0:12"

      PremiereEcoute.PubSub.broadcast("session:#{session.id}", {:clip_progress, %{current_time: 12.5, duration: 200.0}})

      html = render(view)

      assert html =~ "0:12"
      assert html =~ "3:20"
    end

    test "seeking the progress bar broadcasts a seek command", %{conn: conn, session: session} do
      PremiereEcoute.PubSub.subscribe("session:#{session.id}")

      {:ok, view, _html} = live(conn, ~p"/sessions/#{session.share_token}/dashboard")

      PremiereEcoute.PubSub.broadcast("session:#{session.id}", {:clip_progress, %{current_time: 12.5, duration: 200.0}})
      render(view)

      view
      |> element("#clip-progress-bar")
      |> render_hook("clip_seek", %{"position" => 80})

      assert_receive {:clip_command, %{command: "seek", value: 80}}
    end

    test "play/pause buttons reflect the actual playback state", %{conn: conn, session: session} do
      {:ok, view, _html} = live(conn, ~p"/sessions/#{session.share_token}/dashboard")

      broadcast_progress(session, %{current_time: 12.5, duration: 200.0, playing: true})
      render(view)

      assert has_element?(view, "[phx-click='clip_pause'].clip-button-active")
      refute has_element?(view, "[phx-click='clip_play'].clip-button-active")

      broadcast_progress(session, %{current_time: 15.5, duration: 200.0, playing: false})
      render(view)

      assert has_element?(view, "[phx-click='clip_play'].clip-button-active")
      refute has_element?(view, "[phx-click='clip_pause'].clip-button-active")
    end
  end

  defp broadcast_progress(session, payload) do
    PremiereEcoute.PubSub.broadcast("session:#{session.id}", {:clip_progress, payload})
  end
end
