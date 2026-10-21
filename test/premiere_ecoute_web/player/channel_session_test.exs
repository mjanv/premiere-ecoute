defmodule PremiereEcouteWeb.Player.ChannelSessionTest do
  use PremiereEcouteWeb.ChannelCase

  import PremiereEcoute.PlayerFixtures

  alias PremiereEcoute.Apis.Players.PlayerRegistry
  alias PremiereEcoute.Apis.PlayerSupervisor
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcouteWeb.Player.Channel
  alias PremiereEcouteWeb.Player.Socket

  @join %{"proto" => 1, "app_version" => "0.1.0", "session_id" => "7d1f6f0c-2c3b-4b53-a4ad-3a8d1a4f9c11"}

  setup do
    start_supervised({Registry, keys: :unique, name: PlayerRegistry})
    start_supervised({DynamicSupervisor, name: PlayerSupervisor, strategy: :one_for_one})

    user = user_fixture(%{role: :streamer})
    %{access_token: token} = player_tokens(user)
    {:ok, socket} = connect(Socket, %{}, connect_info: %{x_headers: [{"x-access-token", token}]})

    %{user: user, socket: socket}
  end

  defp session_for(user, status) do
    {:ok, album} = Album.create(album_fixture())
    {:ok, session} = ListeningSession.create(%{user_id: user.id, album_id: album.id})
    import Ecto.Query
    from(s in ListeningSession, where: s.id == ^session.id) |> Repo.update_all(set: [status: status])
    session
  end

  test "tells the player there is no session when it joins", %{user: user, socket: socket} do
    {:ok, _, _socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)

    assert_push "session", %{"state" => "none", "source" => nil}
  end

  test "tells the player about the running session when it joins", %{user: user, socket: socket} do
    session_for(user, :active)

    {:ok, _, _socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)

    assert_push "session", %{"state" => "active", "source" => "album", "name" => "Sample Album", "track_count" => 2}
  end

  test "pushes the new state when a session starts and when it stops", %{user: user, socket: socket} do
    {:ok, _, _socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
    assert_push "session", %{"state" => "none"}

    session = session_for(user, :active)
    PremiereEcoute.PubSub.broadcast("playback:#{user.id}", {:session_started, session.id})
    assert_push "session", %{"state" => "active"}

    import Ecto.Query
    from(s in ListeningSession, where: s.id == ^session.id) |> Repo.update_all(set: [status: :stopped])
    PremiereEcoute.PubSub.broadcast("playback:#{user.id}", {:session_stopped, session.id})
    assert_push "session", %{"state" => "none"}
  end

  test "pushes the position again when the track changes", %{user: user, socket: socket} do
    session = session_for(user, :active)
    {:ok, _, _socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
    assert_push "session", %{"state" => "active", "track_number" => nil}

    import Ecto.Query
    [track | _] = ListeningSession.get(session.id).album.tracks
    from(s in ListeningSession, where: s.id == ^session.id) |> Repo.update_all(set: [current_track_id: track.id])
    PremiereEcoute.PubSub.broadcast("playback:#{user.id}", {:player, :new_track, %PremiereEcoute.Apis.Players.PlaybackState{}})

    assert_push "session", %{"state" => "active", "track_number" => 1}
  end

  test "does not push the same state twice", %{user: user, socket: socket} do
    {:ok, _, _socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
    assert_push "session", %{"state" => "none"}

    PremiereEcoute.PubSub.broadcast("playback:#{user.id}", {:session_stopped, 1})
    PremiereEcoute.PubSub.broadcast("playback:#{user.id}", {:player, :new_track, %PremiereEcoute.Apis.Players.PlaybackState{}})

    refute_push "session", _
  end

  test "ignores the other messages of the playback topic", %{user: user, socket: socket} do
    {:ok, _, socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
    assert_push "session", _

    PremiereEcoute.PubSub.broadcast("playback:#{user.id}", {:player, :percent, %PremiereEcoute.Apis.Players.PlaybackState{}})
    PremiereEcoute.PubSub.broadcast("playback:#{user.id}", :whatever)

    refute_push "session", _
    assert Process.alive?(socket.channel_pid)
  end

  defp move_to_track(session, number) do
    import Ecto.Query
    [first, second] = ListeningSession.get(session.id).album.tracks
    track = if number == 1, do: first, else: second
    from(s in ListeningSession, where: s.id == ^session.id) |> Repo.update_all(set: [current_track_id: track.id])
    track
  end

  describe "when the track changes" do
    test "pushes the position as soon as the session says the next track started", %{user: user, socket: socket} do
      session = session_for(user, :active)
      {:ok, _, _socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
      assert_push "session", %{"state" => "active", "track_number" => nil}

      track = move_to_track(session, 1)
      PremiereEcoute.PubSub.broadcast("session:#{session.id}", {:next_track, track})
      assert_push "session", %{"track_number" => 1, "track_count" => 2}

      track = move_to_track(session, 2)
      PremiereEcoute.PubSub.broadcast("session:#{session.id}", {:next_track, track})
      assert_push "session", %{"track_number" => 2}
    end

    test "pushes the position when the previous track starts", %{user: user, socket: socket} do
      session = session_for(user, :active)
      move_to_track(session, 2)
      {:ok, _, _socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
      assert_push "session", %{"track_number" => 2}

      track = move_to_track(session, 1)
      PremiereEcoute.PubSub.broadcast("session:#{session.id}", {:previous_track, track})
      assert_push "session", %{"track_number" => 1}
    end

    test "pushes the position when the player starts the next track, whatever the state before", %{user: user, socket: socket} do
      # Each track of a session ends paused, so the next one is a start, never a "new track".
      session = session_for(user, :active)
      {:ok, _, _socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
      assert_push "session", %{"track_number" => nil}

      move_to_track(session, 1)
      PremiereEcoute.PubSub.broadcast("playback:#{user.id}", {:player, :start, %PremiereEcoute.Apis.Players.PlaybackState{}})
      assert_push "session", %{"track_number" => 1}
    end

    test "follows a session that starts after the player joined", %{user: user, socket: socket} do
      {:ok, _, _socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
      assert_push "session", %{"state" => "none"}

      session = session_for(user, :active)
      PremiereEcoute.PubSub.broadcast("playback:#{user.id}", {:session_started, session.id})
      assert_push "session", %{"state" => "active", "track_number" => nil}

      track = move_to_track(session, 1)
      PremiereEcoute.PubSub.broadcast("session:#{session.id}", {:next_track, track})
      assert_push "session", %{"track_number" => 1}
    end

    test "pushes no session when the session stops", %{user: user, socket: socket} do
      session = session_for(user, :active)
      {:ok, _, _socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
      assert_push "session", %{"state" => "active"}

      import Ecto.Query
      from(s in ListeningSession, where: s.id == ^session.id) |> Repo.update_all(set: [status: :stopped])
      PremiereEcoute.PubSub.broadcast("session:#{session.id}", :stop)
      assert_push "session", %{"state" => "none"}
    end

    test "does not listen to a session that is over", %{user: user, socket: socket} do
      session = session_for(user, :active)
      {:ok, _, socket} = subscribe_and_join(socket, Channel, "desktop:#{user.id}", @join)
      assert_push "session", %{"state" => "active"}

      import Ecto.Query
      from(s in ListeningSession, where: s.id == ^session.id) |> Repo.update_all(set: [status: :stopped])
      PremiereEcoute.PubSub.broadcast("playback:#{user.id}", {:session_stopped, session.id})
      assert_push "session", %{"state" => "none"}

      PremiereEcoute.PubSub.broadcast("session:#{session.id}", {:next_track, nil})
      refute_push "session", _
      assert Process.alive?(socket.channel_pid)
    end
  end
end
