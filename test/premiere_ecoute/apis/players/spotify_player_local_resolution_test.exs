defmodule PremiereEcoute.Apis.Players.SpotifyPlayerLocalResolutionTest do
  use PremiereEcoute.DataCase

  import ExUnit.CaptureLog

  require Logger

  alias PremiereEcoute.Apis.Players.PlaybackState
  alias PremiereEcoute.Apis.Players.SpotifyPlayer
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Discography.Artist

  @synthetic "spotify:local:Artist:Album:Song:215"

  setup do
    user = user_fixture()

    data = %{
      scope: user_scope_fixture(user),
      phx_ref: nil,
      polls: 100,
      failures: 0,
      state: PlaybackState.default()
    }

    device = spawn(fn -> Process.sleep(:infinity) end)
    {:noreply, data} = SpotifyPlayer.handle_info({:device_attached, device, %{session_id: "s1"}}, data)

    {:ok, %{user: user, data: data}}
  end

  defp stored_track do
    {:ok, _} =
      Album.create(%Album{
        provider_ids: %{spotify: "alb1"},
        name: "Album",
        artists: [%Artist{name: "Artist"}],
        release_date: ~D[2020-01-01],
        total_tracks: 1,
        tracks: [%Track{provider_ids: %{spotify: "6rqhFgbbKwnb9MLmUQDhG6"}, name: "Song", track_number: 4, duration_ms: 215_000}]
      })
  end

  defp snapshot(overrides \\ %{}) do
    Map.merge(
      %{
        running: true,
        playback: :playing,
        uri: @synthetic,
        title: "Song",
        artist: "Artist",
        album: "Album",
        track_number: 4,
        position_ms: 12_345,
        length_ms: 215_000,
        volume: 0.5
      },
      overrides
    )
  end

  test "a made-up uri becomes the stored track's Spotify uri", %{data: data} do
    stored_track()

    {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot()}, data)

    assert data.state.item.uri == "spotify:track:6rqhFgbbKwnb9MLmUQDhG6"
  end

  test "an unknown song keeps its made-up uri, so a track change is still seen", %{data: data} do
    {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot()}, data)

    assert data.state.item.uri == @synthetic
  end

  test "a real uri from the player is never looked up", %{data: data} do
    stored_track()
    real = "spotify:track:0000000000000000000000"

    {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot(%{uri: real})}, data)

    assert data.state.item.uri == real
  end

  test "the same track is looked up once, not at every snapshot", %{data: data} do
    {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot()}, data)
    # Stored after the first snapshot: a second lookup would now find it.
    stored_track()

    {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 2, snapshot(%{position_ms: 13_345})}, data)

    assert data.state.item.uri == @synthetic
  end

  test "a new track is looked up again", %{data: data} do
    stored_track()
    {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot()}, data)

    {:noreply, data} =
      SpotifyPlayer.handle_info(
        {:device_snapshot, 2, snapshot(%{uri: "spotify:local:Artist:Album:Other:200", title: "Other", length_ms: 200_000})},
        data
      )

    assert data.state.item.uri == "spotify:local:Artist:Album:Other:200"
  end

  test "a snapshot from a player that sends no track number still resolves", %{data: data} do
    stored_track()

    {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 1, Map.delete(snapshot(), :track_number)}, data)

    assert data.state.item.uri == "spotify:track:6rqhFgbbKwnb9MLmUQDhG6"
  end

  test "the resolution is logged", %{user: user, data: data} do
    previous = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: previous) end)
    stored_track()

    log = capture_log(fn -> SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot()}, data) end)

    assert log =~ "Desktop player track resolved user=#{user.id}"
    assert log =~ "spotify:track:6rqhFgbbKwnb9MLmUQDhG6"
  end

  test "leaving the local mode forgets what was resolved", %{data: data} do
    {:noreply, data} = SpotifyPlayer.handle_info({:device_snapshot, 1, snapshot()}, data)

    refute data |> SpotifyPlayer.Local.leave() |> Map.has_key?(:resolved)
  end
end
