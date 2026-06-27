defmodule PremiereEcouteWeb.HomeLiveTest do
  use PremiereEcouteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession

  setup do
    PremiereEcouteCore.FeatureFlag.enable(:billboards)
    PremiereEcouteCore.FeatureFlag.enable(:listening_sessions)
    PremiereEcouteCore.FeatureFlag.enable(:follow_channels)
    PremiereEcouteCore.FeatureFlag.enable(:playlists)

    :ok
  end

  describe "home" do
    test "displays content for authenticated viewer", %{conn: conn} do
      user = user_fixture(%{role: :streamer})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/home")

      assert html =~ "Premiere Ecoute"
      assert html =~ "Hello"
    end

    test "displays content for authenticated streamer", %{conn: conn} do
      user = user_fixture()
      {:ok, streamer_user} = PremiereEcoute.Accounts.update_user_role(user, :streamer)
      conn = log_in_user(conn, streamer_user)

      {:ok, _lv, html} = live(conn, ~p"/home")

      # Basic content still visible
      assert html =~ "Premiere Ecoute"

      # Streamer action buttons
      assert html =~ "Sessions"
      assert html =~ "Retrospective"

      # Check button links
      assert html =~ "href=\"/sessions/new\""
      assert html =~ "href=\"/sessions\""
      assert html =~ "href=\"/sessions/retrospective\""
    end

    test "flags a stopped session from a followed streamer the viewer did not vote in", %{conn: conn} do
      streamer = user_fixture(%{role: :streamer})
      viewer = user_fixture(%{role: :viewer, twitch: %{user_id: "twitch_viewer_home"}})
      {:ok, _} = Accounts.follow(viewer, streamer)

      {:ok, album} = Album.create(album_fixture())
      {:ok, session} = ListeningSession.create(%{user_id: streamer.id, album_id: album.id})
      {:ok, session} = ListeningSession.start(session)
      {:ok, _session} = ListeningSession.stop(session)

      conn = log_in_user(conn, viewer)

      {:ok, _lv, html} = live(conn, ~p"/home")

      assert html =~ "1 missed"
    end

    test "does not flag a stopped session the viewer voted in", %{conn: conn} do
      streamer = user_fixture(%{role: :streamer})
      viewer = user_fixture(%{role: :viewer, twitch: %{user_id: "twitch_viewer_home_2"}})
      {:ok, _} = Accounts.follow(viewer, streamer)

      {:ok, album} = Album.create(album_fixture())
      {:ok, session} = ListeningSession.create(%{user_id: streamer.id, album_id: album.id})
      {:ok, session} = ListeningSession.start(session)
      {:ok, session} = ListeningSession.stop(session)

      vote_fixture(%{
        viewer_id: "twitch_viewer_home_2",
        session_id: session.id,
        track_id: hd(session.album.tracks).id,
        value: "8"
      })

      conn = log_in_user(conn, viewer)

      {:ok, _lv, html} = live(conn, ~p"/home")

      refute html =~ "missed"
    end
  end
end
