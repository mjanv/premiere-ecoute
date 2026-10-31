defmodule PremiereEcoute.Apis.Players.SpotifyPlayerPlayArgsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Apis.Players.SpotifyPlayer
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Playlist.Track, as: PlaylistTrack
  alias PremiereEcoute.Discography.Single

  setup do
    user = user_fixture()
    scope = user_scope_fixture(user)
    start_supervised({Registry, keys: :unique, name: PremiereEcoute.Apis.Players.PlayerRegistry})
    set_mox_global()
    stub(SpotifyApi, :get_playback_state, fn _scope, _state -> {:ok, PlaybackState.default()} end)
    Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "playback:#{user.id}")
    {:ok, player} = SpotifyPlayer.start_link(user.id)
    test = self()
    device = spawn(fn -> forward(test) end)
    send(player, {:device_attached, device, %{}})
    assert_receive {:player, {:mode, :local}, _state}

    on_exit(fn -> if Process.alive?(player), do: GenServer.stop(player) end)
    %{scope: scope, player: player}
  end

  defp forward(test) do
    receive do
      message ->
        send(test, {:device, message})
        forward(test)
    end
  end

  defp play(scope, player, target) do
    test = self()
    task = Task.async(fn -> SpotifyPlayer.command(scope, {:play, target}, fn -> send(test, :web_api) && {:ok, :web_api} end) end)
    assert_receive {:device, {:command, %{id: id, type: :play_uri, args: args}}}
    send(player, {:device_ack, id, :ok, nil})
    Task.await(task)
    args
  end

  test "an album track carries its track number, so the player can check what plays", %{scope: scope, player: player} do
    track = %Track{provider_ids: %{spotify: "6rqhFgbbKwnb9MLmUQDhG6"}, track_number: 4}

    assert %{uri: "spotify:track:6rqhFgbbKwnb9MLmUQDhG6", track_number: 4} = play(scope, player, track)
  end

  test "a track without a usable number sends none", %{scope: scope, player: player} do
    for number <- [nil, 0, -1] do
      track = %Track{provider_ids: %{spotify: "6rqhFgbbKwnb9MLmUQDhG6"}, track_number: number}
      args = play(scope, player, track)

      assert args == %{uri: "spotify:track:6rqhFgbbKwnb9MLmUQDhG6"}, "number #{inspect(number)}"
    end
  end

  test "singles and playlist tracks have no album position to send", %{scope: scope, player: player} do
    single = %Single{provider_ids: %{spotify: "aaaaaaaaaaaaaaaaaaaaaa"}}
    playlist_track = %PlaylistTrack{provider: :spotify, track_id: "bbbbbbbbbbbbbbbbbbbbbb"}

    assert play(scope, player, single) == %{uri: "spotify:track:aaaaaaaaaaaaaaaaaaaaaa"}
    assert play(scope, player, playlist_track) == %{uri: "spotify:track:bbbbbbbbbbbbbbbbbbbbbb"}
  end

  describe "a playlist as a context" do
    test "is not played: the tracks follow one by one, so nothing needs the Web API", %{scope: scope} do
      playlist = %PremiereEcoute.Discography.Playlist{playlist_id: "37i9dQZF1DXcBWIGoYBM5M", tracks: []}
      test = self()

      assert {:ok, :skipped} = SpotifyPlayer.command(scope, {:play, playlist}, fn -> send(test, :web_api) && {:ok, :web_api} end)

      refute_receive {:device, {:command, _command}}
      refute_received :web_api
    end

    test "an album is still left to the Web API", %{scope: scope} do
      album = %PremiereEcoute.Discography.Album{provider_ids: %{spotify: "x"}}

      assert {:ok, :web_api} = SpotifyPlayer.command(scope, {:play, album}, fn -> {:ok, :web_api} end)
    end
  end

  describe "the exact length of the track" do
    test "is sent with an album track, so the player can pause close to its end", %{scope: scope, player: player} do
      track = %Track{provider_ids: %{spotify: "6rqhFgbbKwnb9MLmUQDhG6"}, track_number: 4, duration_ms: 194_087}

      assert %{uri: "spotify:track:6rqhFgbbKwnb9MLmUQDhG6", track_number: 4, duration_ms: 194_087} = play(scope, player, track)
    end

    test "is sent with a single and a playlist track too", %{scope: scope, player: player} do
      single = %Single{provider_ids: %{spotify: "aaaaaaaaaaaaaaaaaaaaaa"}, duration_ms: 210_000}
      playlist_track = %PlaylistTrack{provider: :spotify, track_id: "bbbbbbbbbbbbbbbbbbbbbb", duration_ms: 180_500}

      assert play(scope, player, single) == %{uri: "spotify:track:aaaaaaaaaaaaaaaaaaaaaa", duration_ms: 210_000}
      assert play(scope, player, playlist_track) == %{uri: "spotify:track:bbbbbbbbbbbbbbbbbbbbbb", duration_ms: 180_500}
    end

    test "is left out when it is not known or makes no sense", %{scope: scope, player: player} do
      for duration <- [nil, 0, -5] do
        track = %Track{provider_ids: %{spotify: "6rqhFgbbKwnb9MLmUQDhG6"}, track_number: 2, duration_ms: duration}

        assert play(scope, player, track) == %{uri: "spotify:track:6rqhFgbbKwnb9MLmUQDhG6", track_number: 2}
      end
    end
  end
end
