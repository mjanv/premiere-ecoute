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

  describe "search and filters" do
    setup %{conn: conn} do
      user = user_fixture(%{role: :streamer})
      {:ok, album} = PremiereEcoute.Discography.Album.create(album_fixture(%{name: "Moon Safari"}))
      {:ok, playlist} = PremiereEcoute.Discography.Playlist.create(playlist_fixture(%{title: "Road Trip", tracks: []}))

      {:ok, album_session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, _playlist_session} = ListeningSession.create(%{user_id: user.id, source: :playlist, playlist_id: playlist.id})
      {:ok, _} = ListeningSession.start(album_session)

      %{conn: log_in_user(conn, user)}
    end

    test "lists every session without filters", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/sessions")

      assert html =~ "Moon Safari"
      assert html =~ "Road Trip"
      assert has_element?(view, "#sessions-filters")
    end

    test "typing in the search bar narrows the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sessions")

      html = view |> form("#sessions-filters", %{q: "moon"}) |> render_change()

      assert html =~ "Moon Safari"
      refute html =~ "Road Trip"
    end

    test "the search text and the selects combine", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sessions")

      html = view |> form("#sessions-filters", %{q: "moon", source: "album"}) |> render_change()
      assert html =~ "Moon Safari"

      html = view |> form("#sessions-filters", %{q: "moon", source: "playlist"}) |> render_change()
      refute html =~ "Moon Safari"
      assert html =~ "No session matches"
    end

    test "filters in the URL are ignored", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/sessions?q=moon&status=active&source=playlist")

      assert html =~ "Moon Safari"
      assert html =~ "Road Trip"
    end

    test "status and source selects filter the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sessions")

      html = view |> form("#sessions-filters", %{status: "active"}) |> render_change()
      assert html =~ "Moon Safari"
      refute html =~ "Road Trip"

      html = view |> form("#sessions-filters", %{status: "", source: "playlist"}) |> render_change()
      assert html =~ "Road Trip"
      refute html =~ "Moon Safari"
    end

    test "the selects keep the chosen option", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sessions")

      view |> form("#sessions-filters", %{source: "playlist"}) |> render_change()

      assert has_element?(view, ~s(#sessions-filters option[value="playlist"][selected]))
    end

    test "shows an empty state with a reset link when nothing matches", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sessions")

      html = view |> form("#sessions-filters", %{q: "zzzz"}) |> render_change()
      assert html =~ "No session matches"

      html = view |> element("#reset-filters") |> render_click()

      assert html =~ "Moon Safari"
      refute has_element?(view, ~s(#sessions-filters input[name="q"][value="zzzz"]))
    end

    test "does not show the no-match state for a user without any session", %{conn: conn} do
      conn = log_in_user(conn, user_fixture(%{role: :streamer}))
      {:ok, _view, html} = live(conn, ~p"/sessions")

      refute html =~ "No session matches"
    end
  end
end
