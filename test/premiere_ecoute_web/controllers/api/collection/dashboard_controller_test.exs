defmodule PremiereEcouteWeb.Api.Collection.DashboardControllerTest do
  use PremiereEcouteWeb.ApiCase, async: false

  import PremiereEcoute.Collections.CollectionSessionFixtures

  alias PremiereEcoute.Collections.CollectionSession.Commands.CloseVoteWindow
  alias PremiereEcoute.Collections.CollectionSession.Commands.CompleteCollectionSession
  alias PremiereEcoute.Collections.CollectionSession.Commands.DecideTrack
  alias PremiereEcoute.Collections.CollectionSession.Commands.OpenVoteWindow
  alias PremiereEcoute.Collections.CollectionSession.Commands.StartCollectionSession
  alias PremiereEcouteCore.CommandBus.Mock, as: CommandBus

  setup_mock(PremiereEcouteCore.CommandBus)

  describe "GET /api/collection" do
    test "returns active collection session for streamer", %{conn: conn} do
      user = user_fixture(%{role: :streamer})
      session = collection_session_fixture(user, %{status: :active})

      response =
        conn
        |> auth(user)
        |> get(~p"/api/collection")
        |> response(200, op(PremiereEcouteWeb.Api.Collection.DashboardController, :show))

      assert response["id"] == session.id
      assert response["status"] == "active"
    end

    test "returns 404 when no active collection session exists", %{conn: conn} do
      user = user_fixture(%{role: :streamer})

      conn
      |> auth(user)
      |> get(~p"/api/collection")
      |> json_response(404)
    end

    test "returns 401 without auth", %{conn: conn} do
      conn
      |> get(~p"/api/collection")
      |> json_response(401)
    end
  end

  describe "POST /api/collection/start" do
    test "dispatches StartCollectionSession and returns ok", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "str1"}})
      session = collection_session_fixture(user, %{status: :pending})

      expect(CommandBus, :apply, fn %StartCollectionSession{session_id: session_id} ->
        assert session_id == session.id
        {:ok, session, []}
      end)

      conn
      |> auth(user)
      |> post(~p"/api/collection/start")
      |> response(200, op(PremiereEcouteWeb.Api.Collection.DashboardController, :start))
    end

    test "returns 404 when no pending session", %{conn: conn} do
      user = user_fixture(%{role: :streamer})

      conn
      |> auth(user)
      |> post(~p"/api/collection/start")
      |> json_response(404)
    end
  end

  describe "POST /api/collection/vote/open" do
    test "dispatches OpenVoteWindow with mode and duration", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "str1"}})
      session = collection_session_fixture(user, %{status: :active})

      expect(CommandBus, :apply, fn %OpenVoteWindow{
                                      session_id: session_id,
                                      selection_mode: mode,
                                      vote_duration: duration
                                    } ->
        assert session_id == session.id
        assert mode == :viewer_vote
        assert duration == 45
        {:ok, session, []}
      end)

      conn
      |> auth(user)
      |> post(~p"/api/collection/vote/open", %{mode: "viewer_vote", duration: 45})
      |> response(200, op(PremiereEcouteWeb.Api.Collection.DashboardController, :open_vote))
    end

    test "defaults duration to 60 when not provided", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "str1"}})
      session = collection_session_fixture(user, %{status: :active})

      expect(CommandBus, :apply, fn %OpenVoteWindow{vote_duration: duration} ->
        assert duration == 60
        {:ok, session, []}
      end)

      conn
      |> auth(user)
      |> post(~p"/api/collection/vote/open", %{mode: "duel"})
      |> response(200, op(PremiereEcouteWeb.Api.Collection.DashboardController, :open_vote))
    end

    test "returns 404 when no active session", %{conn: conn} do
      user = user_fixture(%{role: :streamer})

      conn
      |> auth(user)
      |> post(~p"/api/collection/vote/open", %{mode: "viewer_vote", duration: 60})
      |> json_response(404)
    end
  end

  describe "POST /api/collection/vote/close" do
    test "dispatches CloseVoteWindow and returns ok", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "str1"}})
      session = collection_session_fixture(user, %{status: :active})

      expect(CommandBus, :apply, fn %CloseVoteWindow{session_id: session_id} ->
        assert session_id == session.id
        {:ok, session, []}
      end)

      conn
      |> auth(user)
      |> post(~p"/api/collection/vote/close")
      |> response(200, op(PremiereEcouteWeb.Api.Collection.DashboardController, :close_vote))
    end

    test "returns 404 when no active session", %{conn: conn} do
      user = user_fixture(%{role: :streamer})

      conn
      |> auth(user)
      |> post(~p"/api/collection/vote/close")
      |> json_response(404)
    end
  end

  describe "POST /api/collection/decide" do
    test "dispatches DecideTrack with kept decision", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "str1"}})
      session = collection_session_fixture(user, %{status: :active})

      expect(CommandBus, :apply, fn %DecideTrack{session_id: session_id, decision: decision} ->
        assert session_id == session.id
        assert decision == :kept
        {:ok, session, []}
      end)

      conn
      |> auth(user)
      |> post(~p"/api/collection/decide", %{decision: "kept"})
      |> response(200, op(PremiereEcouteWeb.Api.Collection.DashboardController, :decide))
    end

    test "dispatches DecideTrack with rejected decision", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "str1"}})
      session = collection_session_fixture(user, %{status: :active})

      expect(CommandBus, :apply, fn %DecideTrack{decision: decision} ->
        assert decision == :rejected
        {:ok, session, []}
      end)

      conn
      |> auth(user)
      |> post(~p"/api/collection/decide", %{decision: "rejected"})
      |> response(200, op(PremiereEcouteWeb.Api.Collection.DashboardController, :decide))
    end

    test "returns 422 for invalid decision value", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "str1"}})

      conn
      |> auth(user)
      |> post(~p"/api/collection/decide", %{decision: "banana"})
      |> json_response(422)
    end

    test "returns 404 when no active session", %{conn: conn} do
      user = user_fixture(%{role: :streamer})

      conn
      |> auth(user)
      |> post(~p"/api/collection/decide", %{decision: "kept"})
      |> json_response(404)
    end
  end

  describe "POST /api/collection/complete" do
    test "dispatches CompleteCollectionSession with defaults", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "str1"}})
      session = collection_session_fixture(user, %{status: :active})

      expect(CommandBus, :apply, fn %CompleteCollectionSession{
                                      session_id: session_id,
                                      remove_kept: remove_kept,
                                      remove_rejected: remove_rejected
                                    } ->
        assert session_id == session.id
        assert remove_kept == false
        assert remove_rejected == false
        {:ok, session, []}
      end)

      conn
      |> auth(user)
      |> post(~p"/api/collection/complete")
      |> response(200, op(PremiereEcouteWeb.Api.Collection.DashboardController, :complete))
    end

    test "dispatches CompleteCollectionSession with remove flags", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "str1"}})
      session = collection_session_fixture(user, %{status: :active})

      expect(CommandBus, :apply, fn %CompleteCollectionSession{
                                      remove_kept: remove_kept,
                                      remove_rejected: remove_rejected
                                    } ->
        assert remove_kept == true
        assert remove_rejected == true
        {:ok, session, []}
      end)

      conn
      |> auth(user)
      |> post(~p"/api/collection/complete", %{remove_kept: true, remove_rejected: true})
      |> response(200, op(PremiereEcouteWeb.Api.Collection.DashboardController, :complete))
    end

    test "returns 404 when no active session", %{conn: conn} do
      user = user_fixture(%{role: :streamer})

      conn
      |> auth(user)
      |> post(~p"/api/collection/complete")
      |> json_response(404)
    end
  end
end
