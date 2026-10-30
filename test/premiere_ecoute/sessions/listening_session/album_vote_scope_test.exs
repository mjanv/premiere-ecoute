defmodule PremiereEcoute.Sessions.ListeningSession.AlbumVoteScopeTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Sessions.ListeningSession.Commands.PrepareListeningSession
  alias PremiereEcoute.Sessions.ListeningSession.EventHandler
  alias PremiereEcoute.Sessions.ListeningSession.Events.NextTrackStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.PreviousTrackStarted
  alias PremiereEcoute.Sessions.ListeningSession.Events.SessionStarted
  alias PremiereEcoute.Sessions.ListeningSessionWorker
  alias PremiereEcouteCore.Cache
  alias PremiereEcouteCore.CommandBus

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi.Mock, as: SpotifyApi
  alias PremiereEcoute.Apis.Streaming.TwitchApi.Mock, as: TwitchApi

  @album_options %{"votes" => 0, "scores" => 0, "next_track" => 0, "vote_scope" => "album"}

  setup_all do
    start_supervised({Cache, name: :sessions})
    :ok
  end

  setup do
    Cache.clear(:sessions)
    :ok
  end

  describe "PrepareListeningSession - vote_scope" do
    test "stores the album vote scope in the session options" do
      user = user_fixture()
      album = album_fixture()

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)

      {:ok, session, _} =
        CommandBus.apply(%PrepareListeningSession{
          source: :album,
          user_id: user.id,
          album_id: Map.get(album.provider_ids, :spotify),
          vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
          vote_scope: :album
        })

      assert session.options["vote_scope"] == "album"
    end

    test "defaults to the track vote scope" do
      user = user_fixture()
      album = album_fixture()

      expect(SpotifyApi, :get_album, fn _ -> {:ok, album} end)

      {:ok, session, _} =
        CommandBus.apply(%PrepareListeningSession{
          source: :album,
          user_id: user.id,
          album_id: Map.get(album.provider_ids, :spotify),
          vote_options: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
        })

      assert session.options["vote_scope"] == "track"
    end
  end

  describe "EventHandler - album vote scope" do
    test "opens the album vote when the session starts" do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active, options: @album_options})

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%SessionStarted{source: :album, session_id: session.id, user_id: user.id})

        assert_enqueued worker: ListeningSessionWorker,
                        args: %{"action" => "open_album_vote", "session_id" => session.id, "user_id" => user.id}
      end)
    end

    test "does not open the album vote when the session starts in track scope" do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active})

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%SessionStarted{source: :album, session_id: session.id, user_id: user.id})

        refute_enqueued worker: ListeningSessionWorker, args: %{"action" => "open_album_vote"}
      end)
    end

    test "keeps votes open when the next track starts" do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active, options: @album_options})

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%NextTrackStarted{
          source: :album,
          session_id: session.id,
          user_id: user.id,
          track: %{duration_ms: 200_000}
        })

        refute_enqueued worker: ListeningSessionWorker, args: %{"action" => "close"}
        refute_enqueued worker: ListeningSessionWorker, args: %{"action" => "open_album"}
      end)
    end

    test "keeps votes open when the previous track starts" do
      user = user_fixture()
      session = session_fixture(%{user_id: user.id, status: :active, options: @album_options})

      Oban.Testing.with_testing_mode(:manual, fn ->
        EventHandler.dispatch(%PreviousTrackStarted{
          session_id: session.id,
          user_id: user.id,
          track: %{duration_ms: 200_000}
        })

        refute_enqueued worker: ListeningSessionWorker, args: %{"action" => "close"}
        refute_enqueued worker: ListeningSessionWorker, args: %{"action" => "open_album"}
      end)
    end
  end

  describe "ListeningSessionWorker - open_album_vote" do
    test "opens the vote for the whole album and announces it in chat" do
      user = user_fixture(%{twitch: %{user_id: "1234"}})
      session = session_fixture(%{user_id: user.id, status: :active, options: @album_options})

      expect(TwitchApi, :send_chat_message, fn _scope, msg ->
        assert msg == "Votes are open for the whole album! One vote each, your first vote counts."
        :ok
      end)

      PremiereEcoute.PubSub.subscribe("session:#{session.id}")

      assert :ok =
               perform_job(ListeningSessionWorker, %{
                 "action" => "open_album_vote",
                 "user_id" => user.id,
                 "session_id" => session.id
               })

      assert {:ok, %{id: id, current_track_id: nil, vote_scope: :album}} = Cache.get(:sessions, "1234")
      assert id == session.id

      assert_receive :vote_open
    end
  end
end
