defmodule PremiereEcoute.Sessions.ListeningSessionWorkerTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Album.Track
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSessionWorker
  alias PremiereEcouteCore.Cache

  alias PremiereEcoute.Apis.Streaming.TwitchApi.Mock, as: TwitchApi

  setup_all do
    start_supervised({Cache, name: :sessions})
    :ok
  end

  setup do
    Cache.clear(:sessions)
    :ok
  end

  describe "perform/1 - open_album interlude" do
    test "sends interlude announcement and skips vote when current track is below threshold" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      {:ok, db_album} = Album.create_if_not_exists(album_fixture())
      short_track = album_track_fixture(db_album, "Intro", 13_000)

      session =
        session_fixture(%{
          user_id: user.id,
          status: :active,
          current_track_id: short_track.id,
          options: %{"votes" => 0, "scores" => 0, "next_track" => 0, "interlude_threshold_ms" => 45_000}
        })

      expect(TwitchApi, :send_chat_message, fn _scope, msg ->
        assert msg == "Interlude — no vote for this track"
        :ok
      end)

      assert :ok =
               perform_job(ListeningSessionWorker, %{"action" => "open_album", "user_id" => user.id, "session_id" => session.id})

      assert {:ok, nil} = Cache.get(:sessions, user.twitch.user_id)
    end

    test "opens vote normally when current track is above threshold" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      {:ok, db_album} = Album.create_if_not_exists(album_fixture())
      long_track = album_track_fixture(db_album, "Track One", 210_000)

      session =
        session_fixture(%{
          user_id: user.id,
          status: :active,
          current_track_id: long_track.id,
          options: %{"votes" => 0, "scores" => 0, "next_track" => 0, "interlude_threshold_ms" => 45_000}
        })

      expect(TwitchApi, :send_chat_message, fn _scope, msg ->
        assert msg == "Votes are open !"
        :ok
      end)

      assert :ok =
               perform_job(ListeningSessionWorker, %{"action" => "open_album", "user_id" => user.id, "session_id" => session.id})

      assert {:ok, cache} = Cache.get(:sessions, user.twitch.user_id)
      assert cache.id == session.id
    end

    test "opens vote normally when no interlude threshold is set" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      {:ok, db_album} = Album.create_if_not_exists(album_fixture())
      short_track = album_track_fixture(db_album, "Intro", 13_000)

      session =
        session_fixture(%{
          user_id: user.id,
          status: :active,
          current_track_id: short_track.id,
          options: %{"votes" => 0, "scores" => 0, "next_track" => 0}
        })

      expect(TwitchApi, :send_chat_message, fn _scope, msg ->
        assert msg == "Votes are open !"
        :ok
      end)

      assert :ok =
               perform_job(ListeningSessionWorker, %{"action" => "open_album", "user_id" => user.id, "session_id" => session.id})

      assert {:ok, _} = Cache.get(:sessions, user.twitch.user_id)
    end
  end

  describe "perform/1 - PrepareListeningSession stores interlude_threshold_ms" do
    test "interlude_threshold_ms is persisted in session options for album session" do
      user = user_fixture()
      album = album_fixture()

      expect(PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, :get_album, fn _ -> {:ok, album} end)

      {:ok, session, _} =
        PremiereEcoute.apply(%PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession{
          source: :album,
          user_id: user.id,
          album_id: Map.get(album.provider_ids, :spotify),
          interlude_threshold_ms: 45_000
        })

      assert session.options["interlude_threshold_ms"] == 45_000
    end

    test "interlude_threshold_ms is nil in session options when not set" do
      user = user_fixture()
      album = album_fixture()

      expect(PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, :get_album, fn _ -> {:ok, album} end)

      {:ok, session, _} =
        PremiereEcoute.apply(%PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession{
          source: :album,
          user_id: user.id,
          album_id: Map.get(album.provider_ids, :spotify)
        })

      assert is_nil(session.options["interlude_threshold_ms"])
    end
  end

  describe "perform/1 - PrepareListeningSession stores interlude_threshold_ms for playlist" do
    test "interlude_threshold_ms is persisted in session options for playlist session" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      playlist = playlist_fixture()

      expect(PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, :get_playlist, fn _ -> {:ok, playlist} end)

      {:ok, session, _} =
        PremiereEcoute.apply(%PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession{
          source: :playlist,
          user_id: user.id,
          playlist_id: playlist.playlist_id,
          interlude_threshold_ms: 30_000
        })

      assert session.options["interlude_threshold_ms"] == 30_000
    end
  end

  defp album_track_fixture(album, name, duration_ms) do
    Repo.insert!(%Track{
      album_id: album.id,
      name: name,
      track_number: System.unique_integer([:positive]),
      duration_ms: duration_ms,
      provider_ids: %{spotify: "track_#{System.unique_integer([:positive])}"}
    })
  end
end
