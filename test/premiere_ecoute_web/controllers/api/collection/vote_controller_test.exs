defmodule PremiereEcouteWeb.Api.Collection.VoteControllerTest do
  use PremiereEcouteWeb.ApiCase, async: false

  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Sessions

  setup_mock(PremiereEcoute.Sessions)

  describe "POST /api/collection/vote" do
    test "streamer submits choice 1 on own session", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "str1"}})

      expect(Sessions.Mock, :publish_message, fn %MessageSent{
                                                   broadcaster_id: broadcaster_id,
                                                   user_id: user_id,
                                                   message: message,
                                                   is_streamer: is_streamer
                                                 } ->
        assert broadcaster_id == "str1"
        assert user_id == "str1"
        assert message == "1"
        assert is_streamer == true
        :ok
      end)

      response =
        conn
        |> auth(user)
        |> post(~p"/api/collection/vote", %{choice: 1})
        |> response(200, op(PremiereEcouteWeb.Api.Collection.VoteController, :create))

      assert response["ok"] == true
    end

    test "streamer submits choice 2 on own session", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "str1"}})

      expect(Sessions.Mock, :publish_message, fn %MessageSent{message: message} ->
        assert message == "2"
        :ok
      end)

      response =
        conn
        |> auth(user)
        |> post(~p"/api/collection/vote", %{choice: 2})
        |> response(200, op(PremiereEcouteWeb.Api.Collection.VoteController, :create))

      assert response["ok"] == true
    end

    test "viewer submits choice on broadcaster's session", %{conn: conn} do
      broadcaster = user_fixture(%{role: :streamer, username: "mystreamer", twitch: %{user_id: "str1"}})
      viewer = user_fixture(%{role: :viewer, twitch: %{user_id: "viewer1"}})

      expect(Sessions.Mock, :publish_message, fn %MessageSent{
                                                   broadcaster_id: broadcaster_id,
                                                   user_id: user_id,
                                                   message: message,
                                                   is_streamer: is_streamer
                                                 } ->
        assert broadcaster_id == broadcaster.twitch.user_id
        assert user_id == "viewer1"
        assert message == "1"
        assert is_streamer == false
        :ok
      end)

      response =
        conn
        |> auth(viewer)
        |> post(~p"/api/collection/vote", %{choice: 1, username: "mystreamer"})
        |> response(200, op(PremiereEcouteWeb.Api.Collection.VoteController, :create))

      assert response["ok"] == true
    end

    test "returns 404 when broadcaster username is unknown", %{conn: conn} do
      viewer = user_fixture(%{role: :viewer, twitch: %{user_id: "viewer1"}})

      conn
      |> auth(viewer)
      |> post(~p"/api/collection/vote", %{choice: 1, username: "nobody"})
      |> json_response(404)
    end

    test "returns 422 when viewer omits username", %{conn: conn} do
      viewer = user_fixture(%{role: :viewer, twitch: %{user_id: "viewer1"}})

      conn
      |> auth(viewer)
      |> post(~p"/api/collection/vote", %{choice: 1})
      |> json_response(422)
    end

    test "returns 422 when choice is missing", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "str1"}})

      conn
      |> auth(user)
      |> post(~p"/api/collection/vote", %{})
      |> json_response(422)
    end

    test "returns 422 when choice is not 1 or 2", %{conn: conn} do
      user = user_fixture(%{role: :streamer, twitch: %{user_id: "str1"}})

      conn
      |> auth(user)
      |> post(~p"/api/collection/vote", %{choice: 5})
      |> json_response(422)
    end

    test "returns 401 without auth", %{conn: conn} do
      conn
      |> post(~p"/api/collection/vote", %{choice: 1})
      |> json_response(401)
    end
  end
end
