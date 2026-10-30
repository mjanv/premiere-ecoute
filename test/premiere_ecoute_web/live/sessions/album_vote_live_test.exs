defmodule PremiereEcouteWeb.Sessions.AlbumVoteLiveTest do
  use PremiereEcouteWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Hammox

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective.Report
  alias PremiereEcoute.Sessions.Scores.Vote
  alias PremiereEcouteCore.Cache

  setup :verify_on_exit!

  @album_options %{"votes" => 0, "scores" => 0, "next_track" => 0, "vote_scope" => "album"}

  describe "session selection - album vote toggle" do
    setup do
      flags = [:listening_session_album, :listening_session_playlist]
      Enum.each(flags, &FunWithFlags.enable/1)
      on_exit(fn -> Enum.each(flags, &FunWithFlags.disable/1) end)
    end

    test "prepares an album session with the album vote scope", %{conn: conn} do
      user = user_fixture(%{role: :streamer, spotify: %{user_id: "spotify_user_123", username: "spotifyuser"}})
      album = album_fixture()

      stub(SpotifyApi.Mock, :get_album, fn _ -> {:ok, album} end)

      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/sessions/new")

      view |> element("button[phx-value-source='album']") |> render_click()
      render_hook(view, "select_album", %{"album_id" => Map.get(album.provider_ids, :spotify)})
      render_async(view)

      view
      |> element("form[phx-change='vote_options_preset_change']")
      |> render_change(%{"preset" => "0-10"})

      view |> element("[phx-click='toggle_album_vote']") |> render_click()

      {:error, {:live_redirect, %{to: _}}} = view |> element("[phx-click='prepare_session']") |> render_click()

      session = ListeningSession.all(where: [user_id: user.id]) |> hd()
      assert session.options["vote_scope"] == "album"
    end

    test "does not show the album vote toggle for a playlist session", %{conn: conn} do
      user = user_fixture(%{role: :streamer, spotify: %{user_id: "spotify_user_123", username: "spotifyuser"}})

      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/sessions/new")

      view |> element("button[phx-value-source='playlist']") |> render_click()

      refute has_element?(view, "[phx-click='toggle_album_vote']")
    end
  end

  describe "session page - post-session album vote" do
    setup do
      streamer = user_fixture(%{role: :streamer})
      viewer = user_fixture(%{role: :viewer, twitch: %{user_id: "viewer_twitch"}})
      {:ok, album} = Album.create(album_fixture())

      {:ok, session} =
        ListeningSession.create(%{user_id: streamer.id, album_id: album.id, status: :stopped, options: @album_options})

      {:ok, %{streamer: streamer, viewer: viewer, session: session}}
    end

    test "casts a single vote for the whole album", %{conn: conn, streamer: streamer, viewer: viewer, session: session} do
      {:ok, view, _html} = live(log_in_user(conn, viewer), ~p"/sessions/#{streamer.username}/#{session.share_token}")

      view |> element("[phx-click='open_post_vote_modal']") |> render_click()

      refute has_element?(view, "[phx-click='set_post_vote']")

      view |> element("[phx-click='set_post_album_vote'][phx-value-note='8']") |> render_click()
      view |> element("[phx-click='submit_post_votes']") |> render_click()

      assert [%Vote{scope: :album, track_id: nil, value: "8", viewer_id: "viewer_twitch"}] =
               Vote.all(where: [session_id: session.id])

      refute has_element?(view, "[phx-click='open_post_vote_modal']")
    end
  end

  describe "overlay - album vote" do
    setup do
      start_supervised(PremiereEcoute.Apis.PlayerSupervisor)
      start_supervised({Cache, name: :sessions})
      stub(SpotifyApi.Mock, :get_playback_state, fn _scope, _state -> {:ok, PlaybackState.default()} end)

      user = user_fixture(%{role: :streamer, twitch: %{user_id: "streamer_twitch"}})
      {:ok, album} = Album.create(album_fixture())

      {:ok, session} =
        ListeningSession.create(%{user_id: user.id, album_id: album.id, status: :active, options: @album_options})

      {:ok, session} = ListeningSession.next_track(session)

      for {viewer, value} <- [{"v1", "8"}, {"v2", "6"}] do
        {:ok, _} = Vote.create(%Vote{viewer_id: viewer, session_id: session.id, scope: :album, value: value})
      end

      {:ok, _} = Report.generate(session)

      Cache.put(:sessions, "streamer_twitch", %{
        id: session.id,
        vote_options: session.vote_options,
        current_track_id: nil,
        vote_scope: :album
      })

      {:ok, %{user: user, session: session}}
    end

    test "shows the album score", %{conn: conn, user: user} do
      {:ok, _view, html} = live(log_in_user(conn, user), ~p"/sessions/overlay/#{user.username}?score=viewer")

      assert html =~ "7.0"
    end

    test "keeps the album score open when the next track starts", %{conn: conn, user: user, session: session} do
      {:ok, view, _html} = live(log_in_user(conn, user), ~p"/sessions/overlay/#{user.username}?score=viewer")

      send(view.pid, {:next_track_started, session})

      assert render(view) =~ "7.0"
    end
  end

  describe "session retrospective - album vote" do
    test "shows the album overview without per-track slides", %{conn: conn} do
      streamer = user_fixture(%{role: :streamer})
      {:ok, album} = Album.create(album_fixture())

      {:ok, session} =
        ListeningSession.create(%{user_id: streamer.id, album_id: album.id, status: :stopped, options: @album_options})

      {:ok, _} = Vote.create(%Vote{viewer_id: "v1", session_id: session.id, scope: :album, value: "8"})

      {:ok, view, _html} =
        live(log_in_user(conn, streamer), ~p"/sessions/#{streamer.username}/#{session.share_token}/retrospective")

      html = render_async(view)

      assert html =~ "8.0"
      refute html =~ "data-track0-id"
      refute html =~ hd(album.tracks).name
    end

    test "keeps per-track slides for a track vote session", %{conn: conn} do
      streamer = user_fixture(%{role: :streamer})
      {:ok, album} = Album.create(album_fixture())
      {:ok, session} = ListeningSession.create(%{user_id: streamer.id, album_id: album.id, status: :stopped})

      {:ok, view, _html} =
        live(log_in_user(conn, streamer), ~p"/sessions/#{streamer.username}/#{session.share_token}/retrospective")

      assert render_async(view) =~ "data-track0-id"
    end
  end
end
