defmodule PremiereEcouteWeb.Mcp.Components.Wantlist.SaveCurrentTrackTest do
  use PremiereEcoute.DataCase, async: false

  import PremiereEcoute.AccountsFixtures

  alias Hermes.Server.Frame
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Wantlists
  alias PremiereEcouteWeb.Mcp.Components.Wantlist.SaveCurrentTrack

  setup_mock(Wantlists)

  setup_all do
    start_supervised({PremiereEcouteCore.Cache, name: :playback})
    :ok
  end

  setup do
    PremiereEcouteCore.Cache.clear(:playback)
    :ok
  end

  defp frame(user), do: Frame.assign(%Frame{}, :current_user, user)

  defp playing(id) do
    %PlaybackState{
      is_playing: true,
      progress_ms: 0,
      item: %{
        uri: "spotify:track:#{id}",
        name: "Track",
        duration_ms: 180_000,
        artists: [],
        type: :album,
        track_number: nil,
        album: nil
      }
    }
  end

  describe "execute/2" do
    test "saves the currently playing track for any role" do
      for role <- [:viewer, :streamer, :admin] do
        broadcaster = user_fixture(%{role: :streamer, twitch: %{user_id: "bc-#{role}"}})
        user = user_fixture(%{role: role})

        expect(SpotifyApi, :get_playback_state, fn _scope, %PlaybackState{} ->
          {:ok, playing("spotify123")}
        end)

        expect(Wantlists.Mock, :add_radio_track, fn user_id, spotify_id ->
          assert user_id == user.id
          assert spotify_id == "spotify123"
          {:ok, %Wantlists.WantlistItem{id: 1}}
        end)

        assert {:reply, resp, _} =
                 SaveCurrentTrack.execute(%{broadcaster_twitch_id: broadcaster.twitch.user_id}, frame(user))

        assert [%{"text" => "Track saved to wantlist."}] = resp.content
      end
    end

    test "returns error when broadcaster is not found" do
      user = user_fixture()

      assert {:reply, resp, _} =
               SaveCurrentTrack.execute(%{broadcaster_twitch_id: "unknown-twitch-id"}, frame(user))

      assert resp.isError == true
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "Broadcaster not found"
    end

    test "returns error when no track is currently playing" do
      broadcaster = user_fixture(%{role: :streamer, twitch: %{user_id: "bc-no-track"}})
      user = user_fixture()

      expect(SpotifyApi, :get_playback_state, fn _scope, %PlaybackState{} ->
        {:ok, PlaybackState.default()}
      end)

      assert {:reply, resp, _} =
               SaveCurrentTrack.execute(%{broadcaster_twitch_id: broadcaster.twitch.user_id}, frame(user))

      assert resp.isError == true
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "No track currently playing"
    end

    test "returns error when playback state fetch fails" do
      broadcaster = user_fixture(%{role: :streamer, twitch: %{user_id: "bc-error"}})
      user = user_fixture()

      expect(SpotifyApi, :get_playback_state, fn _scope, %PlaybackState{} ->
        {:error, :timeout}
      end)

      assert {:reply, resp, _} =
               SaveCurrentTrack.execute(%{broadcaster_twitch_id: broadcaster.twitch.user_id}, frame(user))

      assert resp.isError == true
    end

    test "returns error when add_radio_track fails" do
      broadcaster = user_fixture(%{role: :streamer, twitch: %{user_id: "bc-save-fail"}})
      user = user_fixture()

      expect(SpotifyApi, :get_playback_state, fn _scope, %PlaybackState{} ->
        {:ok, playing("spotify999")}
      end)

      expect(Wantlists.Mock, :add_radio_track, fn _user_id, _spotify_id ->
        {:error, :not_found}
      end)

      assert {:reply, resp, _} =
               SaveCurrentTrack.execute(%{broadcaster_twitch_id: broadcaster.twitch.user_id}, frame(user))

      assert resp.isError == true
      assert [%{"text" => msg}] = resp.content
      assert msg =~ "could not be saved"
    end
  end
end
