defmodule PremiereEcoute.Apis.Players.SpotifyPlayerCommandTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Apis.Players.SpotifyPlayer
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Playlist.Track, as: PlaylistTrack
  alias PremiereEcoute.Discography.Single

  setup do
    user = user_fixture()
    {:ok, %{user: user, scope: user_scope_fixture(user)}}
  end

  describe "command/3 without a running player" do
    test "uses the Web API when the player registry is not started", %{scope: scope} do
      assert {:ok, :web_api} = SpotifyPlayer.command(scope, :pause, fn -> {:ok, :web_api} end)
    end

    test "uses the Web API when the user has no player process", %{scope: scope} do
      start_supervised({Registry, keys: :unique, name: PremiereEcoute.Apis.Players.PlayerRegistry})

      assert {:ok, :web_api} = SpotifyPlayer.command(scope, :pause, fn -> {:ok, :web_api} end)
    end
  end

  describe "command/3 in api mode" do
    setup %{user: user} do
      start_supervised({Registry, keys: :unique, name: PremiereEcoute.Apis.Players.PlayerRegistry})
      set_mox_global()
      stub(SpotifyApi, :get_playback_state, fn _scope, _state -> {:ok, PlaybackState.default()} end)
      {:ok, player} = SpotifyPlayer.start_link(user.id)
      on_exit(fn -> if Process.alive?(player), do: GenServer.stop(player) end)
      {:ok, %{player: player}}
    end

    test "uses the Web API", %{scope: scope} do
      track = %Track{provider_ids: %{spotify: "6rqhFgbbKwnb9MLmUQDhG6"}}

      assert {:ok, :web_api} = SpotifyPlayer.command(scope, {:play, track}, fn -> {:ok, :web_api} end)
    end
  end

  describe "command/3 in local mode" do
    setup %{user: user} do
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
      {:ok, %{player: player, device: device}}
    end

    test "plays a track on the desktop player and returns its uri", %{scope: scope, player: player} do
      task = command_async(scope, {:play, %Track{provider_ids: %{spotify: "6rqhFgbbKwnb9MLmUQDhG6"}}})

      assert_receive {:device,
                      {:command, %{id: id, type: :play_uri, args: %{uri: "spotify:track:6rqhFgbbKwnb9MLmUQDhG6"}, ttl_ms: 10_000}}}

      send(player, {:device_ack, id, :ok, nil})

      assert Task.await(task) == {:ok, "spotify:track:6rqhFgbbKwnb9MLmUQDhG6"}
      refute_received :web_api
    end

    test "plays singles and playlist tracks", %{scope: scope, player: player} do
      for {target, uri} <- [
            {%Single{provider_ids: %{spotify: "aaaaaaaaaaaaaaaaaaaaaa"}}, "spotify:track:aaaaaaaaaaaaaaaaaaaaaa"},
            {%PlaylistTrack{provider: :spotify, track_id: "bbbbbbbbbbbbbbbbbbbbbb"}, "spotify:track:bbbbbbbbbbbbbbbbbbbbbb"}
          ] do
        task = command_async(scope, {:play, target})
        assert_receive {:device, {:command, %{id: id, type: :play_uri, args: %{uri: ^uri}}}}
        send(player, {:device_ack, id, :ok, nil})
        assert Task.await(task) == {:ok, uri}
      end
    end

    test "uses the Web API when the desktop player did not execute the command", %{scope: scope, player: player} do
      for status <- [:rejected, :expired, :error] do
        task = command_async(scope, {:play, %Track{provider_ids: %{spotify: "6rqhFgbbKwnb9MLmUQDhG6"}}})
        assert_receive {:device, {:command, %{id: id}}}
        send(player, {:device_ack, id, status, "nope"})

        assert Task.await(task) == {:ok, :web_api}
      end
    end

    test "does not use the Web API when the command may have been executed", %{scope: scope, player: player} do
      task = command_async(scope, {:play, %Track{provider_ids: %{spotify: "6rqhFgbbKwnb9MLmUQDhG6"}}})
      assert_receive {:device, {:command, %{id: id}}}

      send(player, {:command_expired, id})

      assert Task.await(task) == {:error, :unknown}
      refute_received :web_api
    end

    test "does not use the Web API when the device disconnects before acking", %{scope: scope, device: device} do
      task = command_async(scope, {:play, %Track{provider_ids: %{spotify: "6rqhFgbbKwnb9MLmUQDhG6"}}})
      assert_receive {:device, {:command, _command}}

      Process.exit(device, :kill)

      assert Task.await(task) == {:error, :unknown}
      refute_received :web_api
    end

    test "uses the Web API for what the desktop player cannot play", %{scope: scope} do
      for target <- [%Album{provider_ids: %{spotify: "x"}}, %PlaybackState{item: %{uri: "spotify:track:1"}, progress_ms: 5}] do
        assert Task.await(command_async(scope, {:play, target})) == {:ok, :web_api}
      end

      refute_receive {:device, {:command, _command}}
    end

    test "pauses by toggling when playing", %{scope: scope, player: player} do
      snapshot(player, 1, %{playback: :playing})

      task = command_async(scope, :pause)
      assert_receive {:device, {:command, %{id: id, type: :toggle_play_pause, args: args}}}
      assert args == %{}
      send(player, {:device_ack, id, :ok, nil})

      assert Task.await(task) == {:ok, :paused}
    end

    test "does not toggle when already paused", %{scope: scope, player: player} do
      snapshot(player, 1, %{playback: :paused})

      assert Task.await(command_async(scope, :pause)) == {:ok, :paused}
      refute_receive {:device, {:command, _command}}
    end

    test "reports the active device from the desktop player", %{scope: scope, player: player} do
      snapshot(player, 1, %{running: true})
      assert Task.await(command_async(scope, :active_device)) == {:ok, :active}

      snapshot(player, 2, %{running: false, playback: :stopped, uri: nil})
      assert Task.await(command_async(scope, :active_device)) == {:error, :no_active_device}
    end

    test "leaves shuffle and repeat alone", %{scope: scope} do
      assert Task.await(command_async(scope, {:shuffle, false})) == {:ok, :skipped}
      assert Task.await(command_async(scope, {:repeat, :off})) == {:ok, :skipped}
    end
  end

  defp command_async(scope, command) do
    test = self()
    Task.async(fn -> SpotifyPlayer.command(scope, command, fn -> send(test, :web_api) && {:ok, :web_api} end) end)
  end

  defp snapshot(player, seq, overrides) do
    snapshot =
      Map.merge(
        %{
          running: true,
          playback: :playing,
          uri: "spotify:track:6rqhFgbbKwnb9MLmUQDhG6",
          title: "Song",
          artist: "Artist",
          album: "Album",
          position_ms: 1,
          length_ms: 100_000,
          volume: 0.5
        },
        overrides
      )

    send(player, {:device_snapshot, seq, snapshot})
    :sys.get_state(player)
  end

  defp forward(test) do
    receive do
      message ->
        send(test, {:device, message})
        forward(test)
    end
  end
end
