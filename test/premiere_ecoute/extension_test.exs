defmodule PremiereEcoute.ExtensionTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Extension
  alias PremiereEcouteCore.Cache

  describe "get_current_track/1" do
    setup do
      start_supervised({Cache, name: :playback})
      stub(SpotifyApi, :get_playback_state, fn _scope, _state -> {:ok, %{}} end)
      :ok
    end

    test "successfully gets current track via TrackReader delegation" do
      user =
        user_fixture(%{
          twitch: %{user_id: "broadcaster123"},
          spotify: %{user_id: "spotify_user_123"}
        })

      broadcaster_id = user.twitch.user_id

      expect(SpotifyApi, :get_playback_state, fn _scope, %{} ->
        {:ok,
         %{
           "is_playing" => true,
           "item" => %{
             "id" => "track_123",
             "name" => "Test Song",
             "artists" => [%{"name" => "Test Artist"}],
             "album" => %{"name" => "Test Album"},
             "track_number" => 1,
             "duration_ms" => 180_000,
             "preview_url" => nil
           }
         }}
      end)

      result = Extension.get_current_track(broadcaster_id)

      assert {:ok, track_data} = result
      assert track_data.name == "Test Song"
      assert track_data.artist == "Test Artist"
    end

    test "returns error when user not found via TrackReader delegation" do
      result = Extension.get_current_track("nonexistent")
      assert result == {:error, :no_user}
    end
  end
end
