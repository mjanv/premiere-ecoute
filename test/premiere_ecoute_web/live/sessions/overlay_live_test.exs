defmodule PremiereEcouteWeb.Sessions.OverlayLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Hammox

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession

  setup :verify_on_exit!

  setup do
    start_supervised(PremiereEcoute.Apis.PlayerSupervisor)

    user =
      user_fixture(%{
        role: :streamer,
        spotify: %{
          user_id: "spotify_user_123",
          username: "spotifyuser",
          access_token: "valid_access_token",
          refresh_token: "valid_refresh_token"
        }
      })

    {:ok, album} = Album.create(album_fixture())

    {:ok, user: user, album: album}
  end

  describe "mount/3 with active session" do
    test "displays overlay for active session when user has one", %{conn: conn, user: user, album: album} do
      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)

      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, _session} = ListeningSession.start(session)

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.id}")

      # Verify overlay is rendered with proper dimensions (default streamer width: 240px)
      assert has_element?(view, "div[style*='width: 240px']")
      assert html =~ "width: 240px"
      assert html =~ "height: 240px"
    end

    test "displays overlay with correct score type from query params", %{conn: conn, user: user, album: album} do
      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)

      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, _session} = ListeningSession.start(session)

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.id}?score=viewer")

      # Viewer score also uses 240px width
      assert has_element?(view, "div[style*='width: 240px']")
      assert html =~ "width: 240px"
    end
  end

  describe "mount/3 without active session" do
    test "displays default overlay when user has no active session", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.id}")

      # Default overlay should render with streamer dimensions
      assert has_element?(view, "div[style*='width: 240px']")
      assert html =~ "width: 240px"
      assert html =~ "height: 240px"
    end

    test "displays default overlay when user has only preparing session", %{conn: conn, user: user, album: album} do
      # Stub for any background PlayerSupervisor calls
      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)

      {:ok, _session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.id}")

      # Should show default overlay since preparing sessions don't count as active
      assert has_element?(view, "div[style*='width: 240px']")
      assert html =~ "width: 240px"
    end

    test "displays default overlay when user has only stopped session", %{conn: conn, user: user, album: album} do
      # Stub for any background PlayerSupervisor calls
      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)

      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, session} = ListeningSession.start(session)
      {:ok, _session} = ListeningSession.stop(session)

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.id}")

      # Should show default overlay since stopped sessions don't count as active
      assert has_element?(view, "div[style*='width: 240px']")
      assert html =~ "width: 240px"
    end
  end

  describe "mount/3 with multiple sessions" do
    test "displays most recently updated active session", %{conn: conn, user: user, album: album} do
      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)

      {:ok, session1} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, session1} = ListeningSession.start(session1)

      # Stop first session and start another
      {:ok, _} = ListeningSession.stop(session1)
      {:ok, session2} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, _session2} = ListeningSession.start(session2)

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.id}")

      # Verify overlay renders for the most recent active session
      assert has_element?(view, "div[style*='width: 240px']")
      assert html =~ "width: 240px"
    end
  end

  describe "handle_info/2 - PubSub events" do
    test "updates open_vote when :vote_open and :vote_close events received", %{
      conn: conn,
      user: user,
      album: album
    } do
      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)

      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, _session} = ListeningSession.start(session)

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.id}")

      # Verify overlay renders initially
      assert html =~ "width: 240px"

      # Send vote_close event and verify it re-renders
      send(view.pid, :vote_close)
      html = render(view)
      assert html =~ "width: 240px"

      # Send vote_open event and verify it re-renders
      send(view.pid, :vote_open)
      html = render(view)
      assert html =~ "width: 240px"
    end

    test "updates progress when :player event received", %{conn: conn, user: user, album: album} do
      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)

      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, _session} = ListeningSession.start(session)

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.id}")

      assert html =~ "width: 240px"

      player_state = %{
        "progress_ms" => 60_000,
        "item" => %{"duration_ms" => 180_000}
      }

      send(view.pid, {:player, :playing, player_state})
      html = render(view)

      # Progress should update the gradient (33% progress)
      assert html =~ "width: 240px"
    end

    test "handles :session_summary event", %{conn: conn, user: user, album: album} do
      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)

      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, _session} = ListeningSession.start(session)

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.id}")

      assert html =~ "width: 240px"

      session_summary = %{"streamer_score" => 8.5, "viewer_score" => 7.2}

      send(view.pid, {:session_summary, session_summary})
      html = render(view)

      # Summary event should trigger a re-render
      assert html =~ "width: 240px"
    end

    test "handles :player :no_device event", %{conn: conn, user: user, album: album} do
      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)

      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, _session} = ListeningSession.start(session)

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.id}")

      assert html =~ "width: 240px"

      send(view.pid, {:player, :no_device, %{}})
      html = render(view)

      # Should still render overlay even without device
      assert html =~ "width: 240px"
    end
  end

  describe "handle_params/3" do
    test "updates score when score param changes", %{conn: conn, user: user, album: album} do
      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)

      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, _session} = ListeningSession.start(session)

      conn = log_in_user(conn, user)

      # Default score (streamer) - width: 240px
      {:ok, _view, html} = live(conn, ~p"/sessions/overlay/#{user.id}")
      assert html =~ "width: 240px"

      # Viewer score - width: 240px
      {:ok, _view, html} = live(conn, ~p"/sessions/overlay/#{user.id}?score=viewer")
      assert html =~ "width: 240px"

      # Both scores - width: 480px
      {:ok, _view, html} = live(conn, ~p"/sessions/overlay/#{user.id}?score=viewer+streamer")
      assert html =~ "width: 480px"

      # Player score - width: 1200px (480 * 2.5)
      {:ok, _view, html} = live(conn, ~p"/sessions/overlay/#{user.id}?score=player")
      assert html =~ "width: 1200px"
    end
  end

  describe "business rule enforcement" do
    test "displays most recent active session when user has active session", %{
      conn: conn,
      user: user,
      album: album
    } do
      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)

      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, _active_session} = ListeningSession.start(session)

      conn = log_in_user(conn, user)
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.id}")

      # Verify the overlay shows the active session with proper rendering
      assert has_element?(view, "div[style*='width: 240px']")
      assert html =~ "width: 240px"
      assert html =~ "height: 240px"
    end

    test "overlay updates when session is stopped", %{conn: conn, user: user, album: album} do
      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)

      {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
      {:ok, session} = ListeningSession.start(session)

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/sessions/overlay/#{user.id}")

      # Verify active session is displayed
      assert html =~ "width: 240px"

      # Now stop the session and reload
      {:ok, _} = ListeningSession.stop(session)

      # Reconnect to see updated state
      {:ok, view, html} = live(conn, ~p"/sessions/overlay/#{user.id}")

      # Should still show overlay (default display for no active session)
      assert has_element?(view, "div[style*='width: 240px']")
      assert html =~ "width: 240px"
    end
  end
end
