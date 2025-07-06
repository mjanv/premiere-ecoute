defmodule PremiereEcoute.Apis.TwitchApi.EventSubTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.TwitchApi

  describe "get_event_subscriptions/2" do
    test "read the list of existing subscriptions" do
      scope =
        user_scope_fixture(
          user_fixture(%{
            twitch_user_id: "1234",
            twitch_access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"
          })
        )

      ApiMock.stub(
        TwitchApi,
        path: {:get, "/helix/eventsub/subscriptions"},
        response: "twitch_api/eventsub/get_event_subscriptions/response.json",
        params: %{"user_id" => "1234"},
        status: 200
      )

      {:ok, subscriptions} = TwitchApi.get_event_subscriptions(scope)

      assert subscriptions == [
               %{"id" => "26b1c993-bfcf-44d9-b876-379dacafe75a", "type" => "stream.online"},
               %{"id" => "35016908-41ff-33ce-7879-61b8dfc2ee16", "type" => "user.update"}
             ]
    end
  end

  describe "subscribe/2" do
    test "can subscribe to a Twitch event" do
      scope =
        user_scope_fixture(
          user_fixture(%{
            twitch_user_id: "1234",
            twitch_access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"
          })
        )

      ApiMock.stub(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        request: "twitch_api/eventsub/create_event_subscription/request.json",
        response: "twitch_api/eventsub/create_event_subscription/response.json",
        status: 202
      )

      {:ok, subscription} = TwitchApi.subscribe(scope, "channel.follow")

      assert subscription == %{
               "condition" => %{"user_id" => "1234"},
               "cost" => 1,
               "created_at" => "2020-11-10T14:32:18.730260295Z",
               "id" => "26b1c993-bfcf-44d9-b876-379dacafe75a",
               "status" => "webhook_callback_verification_pending",
               "transport" => %{
                 "callback" => "https://this-is-a-callback.com",
                 "method" => "webhook"
               },
               "type" => "user.update",
               "version" => "1"
             }
    end

    test "cannnot resubscribe to a Twitch event" do
      scope =
        user_scope_fixture(
          user_fixture(%{
            twitch_user_id: "1234",
            twitch_access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"
          })
        )

      ApiMock.stub(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        request: "twitch_api/eventsub/create_event_subscription/request.json",
        response: "twitch_api/eventsub/create_event_subscription/response.json",
        status: 202
      )

      {:ok, _} = TwitchApi.subscribe(scope, "channel.follow")

      ApiMock.stub(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        request: "twitch_api/eventsub/create_event_subscription/request.json",
        response: %{
          "error" => "Conflict",
          "message" => "subscription already exists",
          "status" => 409
        },
        status: 409
      )

      {:error, reason} = TwitchApi.subscribe(scope, "channel.follow")

      assert reason == "Failed to subscribe to channel.follow"
    end
  end

  describe "unsubscribe/2" do
    test "can unsubscribe from a Twitch event" do
      scope =
        user_scope_fixture(
          user_fixture(%{
            twitch_user_id: "1234",
            twitch_access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"
          })
        )

      ApiMock.stub(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        request: "twitch_api/eventsub/create_event_subscription/request.json",
        response: "twitch_api/eventsub/create_event_subscription/response.json",
        status: 202
      )

      {:ok, _} = TwitchApi.subscribe(scope, "channel.follow")

      ApiMock.stub(
        TwitchApi,
        path: {:delete, "/helix/eventsub/subscriptions"},
        params: %{"id" => "26b1c993-bfcf-44d9-b876-379dacafe75a"},
        status: 204
      )

      {:ok, id} = TwitchApi.unsubscribe(scope, "channel.follow")

      assert id == "26b1c993-bfcf-44d9-b876-379dacafe75a"
    end

    test "cannot unsubscribe from an unknown Twitch event" do
      scope =
        user_scope_fixture(
          user_fixture(%{
            twitch_user_id: "5678",
            twitch_access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"
          })
        )

      {:error, reason} = TwitchApi.unsubscribe(scope, "channel.follow")

      assert reason == "Unknown subscription"
    end
  end

  describe "cancel_all_subscriptions/1" do
    test "unsubscribe from all known subscriptions" do
      scope =
        user_scope_fixture(
          user_fixture(%{
            twitch_user_id: "1234",
            twitch_access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"
          })
        )

      ApiMock.expect(
        TwitchApi,
        1,
        path: {:get, "/helix/eventsub/subscriptions"},
        response: "twitch_api/eventsub/get_event_subscriptions/response.json",
        params: %{"user_id" => "1234"},
        status: 200
      )

      ApiMock.expect(
        TwitchApi,
        1,
        path: {:delete, "/helix/eventsub/subscriptions"},
        params: %{"id" => "26b1c993-bfcf-44d9-b876-379dacafe75a"},
        status: 204
      )

      ApiMock.expect(
        TwitchApi,
        1,
        path: {:delete, "/helix/eventsub/subscriptions"},
        params: %{"id" => "35016908-41ff-33ce-7879-61b8dfc2ee16"},
        status: 204
      )

      {:ok, ids} = TwitchApi.cancel_all_subscriptions(scope)

      assert ids == [
               "26b1c993-bfcf-44d9-b876-379dacafe75a",
               "35016908-41ff-33ce-7879-61b8dfc2ee16"
             ]
    end

    test "cannot unsubscribe from all known subscriptions in case API error" do
      scope =
        user_scope_fixture(
          user_fixture(%{
            twitch_user_id: "1234",
            twitch_access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"
          })
        )

      ApiMock.expect(
        TwitchApi,
        1,
        path: {:get, "/helix/eventsub/subscriptions"},
        response: "twitch_api/eventsub/get_event_subscriptions/response.json",
        params: %{"user_id" => "1234"},
        status: 200
      )

      ApiMock.expect(
        TwitchApi,
        1,
        path: {:delete, "/helix/eventsub/subscriptions"},
        params: %{"id" => "26b1c993-bfcf-44d9-b876-379dacafe75a"},
        status: 204
      )

      ApiMock.expect(
        TwitchApi,
        1,
        path: {:delete, "/helix/eventsub/subscriptions"},
        params: %{"id" => "35016908-41ff-33ce-7879-61b8dfc2ee16"},
        response: %{"error" => "The subscription was not found."},
        status: 404
      )

      {:error, reason} = TwitchApi.cancel_all_subscriptions(scope)

      assert reason == "Cannot cancel all subscriptions"
    end
  end
end
