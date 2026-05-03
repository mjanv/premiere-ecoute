defmodule PremiereEcouteWeb.Api.Wantlist.TrackControllerTest do
  use PremiereEcouteWeb.ApiCase, async: false

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcouteWeb.Api.Wantlist.TrackController

  setup_mock(PremiereEcoute.Wantlists)

  setup_all do
    start_supervised({PremiereEcouteCore.Cache, name: :playback})
    :ok
  end

  setup do
    PremiereEcouteCore.Cache.clear(:playback)
    :ok
  end

  describe "POST /api/wantlist/tracks/current" do
    test "saves the currently playing track to the wantlist", %{conn: conn} do
      broadcaster = user_fixture(%{role: :streamer, twitch: %{user_id: "broadcaster123"}})
      viewer = user_fixture(%{role: :viewer})

      expect(SpotifyApi, :get_playback_state, fn _scope, %{} ->
        {:ok, %{"item" => %{"id" => "spotify123", "name" => "Some Track", "artists" => [%{"name" => "Artist"}]}}}
      end)

      expect(PremiereEcoute.Wantlists.Mock, :add_radio_track, fn user_id, spotify_id ->
        assert user_id == viewer.id
        assert spotify_id == "spotify123"
        {:ok, %PremiereEcoute.Wantlists.WantlistItem{id: 42}}
      end)

      conn
      |> auth(viewer)
      |> post(~p"/api/wantlist/tracks/current?broadcaster_id=#{broadcaster.twitch.user_id}")
      |> response(200, op(TrackController, :create))
    end

    test "returns 400 when broadcaster_id param is missing", %{conn: conn} do
      viewer = user_fixture(%{role: :viewer})

      conn
      |> auth(viewer)
      |> post(~p"/api/wantlist/tracks/current")
      |> json_response(400)
    end

    test "returns 404 when broadcaster is not found", %{conn: conn} do
      viewer = user_fixture(%{role: :viewer})

      conn
      |> auth(viewer)
      |> post(~p"/api/wantlist/tracks/current?broadcaster_id=unknown")
      |> json_response(404)
    end

    test "returns 404 when no track is currently playing", %{conn: conn} do
      broadcaster = user_fixture(%{role: :streamer, twitch: %{user_id: "broadcaster123"}})
      viewer = user_fixture(%{role: :viewer})

      expect(SpotifyApi, :get_playback_state, fn _scope, %{} ->
        {:ok, %{}}
      end)

      conn
      |> auth(viewer)
      |> post(~p"/api/wantlist/tracks/current?broadcaster_id=#{broadcaster.twitch.user_id}")
      |> json_response(404)
    end

    test "returns 422 when add_radio_track fails", %{conn: conn} do
      broadcaster = user_fixture(%{role: :streamer, twitch: %{user_id: "broadcaster123"}})
      viewer = user_fixture(%{role: :viewer})

      expect(SpotifyApi, :get_playback_state, fn _scope, %{} ->
        {:ok, %{"item" => %{"id" => "spotify123", "name" => "Some Track", "artists" => []}}}
      end)

      expect(PremiereEcoute.Wantlists.Mock, :add_radio_track, fn _user_id, _spotify_id ->
        {:error, :not_found}
      end)

      conn
      |> auth(viewer)
      |> post(~p"/api/wantlist/tracks/current?broadcaster_id=#{broadcaster.twitch.user_id}")
      |> json_response(422)
    end

    test "returns 401 without authorization header", %{conn: conn} do
      conn
      |> post(~p"/api/wantlist/tracks/current?broadcaster_id=abc")
      |> json_response(401)
    end
  end
end
