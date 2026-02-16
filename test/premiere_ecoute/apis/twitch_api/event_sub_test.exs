defmodule PremiereEcoute.Apis.TwitchApi.EventSubTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.TwitchApi
  alias PremiereEcouteCore.Cache

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup do
    scope =
      user_scope_fixture(
        user_fixture(%{
          twitch: %{user_id: "1234", access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"}
        })
      )

    Cache.put(:tokens, :twitch, "token")

    {:ok, %{scope: scope}}
  end

  describe "get_event_subscriptions/2" do
    test "read the list of existing subscriptions", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        response: "twitch_api/eventsub/get_event_subscriptions/response.json",
        params: %{"user_id" => "1234"},
        status: 200
      )

      {:ok, subscriptions} = TwitchApi.get_event_subscriptions(scope)

      assert subscriptions == [
               %{
                 "id" => "26b1c993-bfcf-44d9-b876-379dacafe75a",
                 "type" => "stream.online",
                 "condition" => %{"broadcaster_user_id" => "1234"},
                 "cost" => 1,
                 "created_at" => "2020-11-10T20:08:33.12345678Z",
                 "status" => "enabled",
                 "transport" => %{"callback" => "https://this-is-a-callback.com", "method" => "webhook"},
                 "version" => "1"
               },
               %{
                 "id" => "35016908-41ff-33ce-7879-61b8dfc2ee16",
                 "type" => "user.update",
                 "condition" => %{"user_id" => "1234"},
                 "cost" => 0,
                 "created_at" => "2020-11-10T14:32:18.730260295Z",
                 "status" => "webhook_callback_verification_pending",
                 "transport" => %{"callback" => "https://this-is-a-callback.com", "method" => "webhook"},
                 "version" => "1"
               }
             ]
    end
  end

  describe "subscribe/2" do
    test "can subscribe to a Twitch event", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
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

    test "cannnot resubscribe to a Twitch event", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        request: "twitch_api/eventsub/create_event_subscription/request.json",
        response: "twitch_api/eventsub/create_event_subscription/response.json",
        status: 202
      )

      {:ok, _} = TwitchApi.subscribe(scope, "channel.follow")

      ApiMock.expect(
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

      assert reason == "Twitch API error: 409"
    end
  end

  describe "unsubscribe/2" do
    test "can unsubscribe from a Twitch event", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        request: "twitch_api/eventsub/create_event_subscription/request.json",
        response: "twitch_api/eventsub/create_event_subscription/response.json",
        status: 202
      )

      {:ok, _} = TwitchApi.subscribe(scope, "channel.follow")

      ApiMock.expect(
        TwitchApi,
        path: {:delete, "/helix/eventsub/subscriptions"},
        params: %{"id" => "26b1c993-bfcf-44d9-b876-379dacafe75a"},
        status: 204
      )

      {:ok, id} = TwitchApi.unsubscribe(scope, "channel.follow")

      assert id == "26b1c993-bfcf-44d9-b876-379dacafe75a"
    end

    test "unsubscribing when not in cache but subscription exists on Twitch" do
      scope =
        user_scope_fixture(
          user_fixture(%{
            twitch: %{user_id: "5678", access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"}
          })
        )

      # Cache miss, so it will fetch from Twitch API
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        response: %{
          "data" => [
            %{
              "id" => "abc-123-def",
              "type" => "channel.follow",
              "condition" => %{"user_id" => "5678"},
              "cost" => 1,
              "created_at" => "2020-11-10T20:08:33.12345678Z",
              "status" => "enabled",
              "transport" => %{"callback" => "https://this-is-a-callback.com", "method" => "webhook"},
              "version" => "2"
            }
          ],
          "total" => 1,
          "total_cost" => 1,
          "max_total_cost" => 10_000
        },
        params: %{"user_id" => "5678"},
        status: 200
      )

      # Then it will delete the found subscription
      ApiMock.expect(
        TwitchApi,
        path: {:delete, "/helix/eventsub/subscriptions"},
        params: %{"id" => "abc-123-def"},
        status: 204
      )

      {:ok, id} = TwitchApi.unsubscribe(scope, "channel.follow")

      assert id == "abc-123-def"
    end

    test "unsubscribing when not in cache and subscription does not exist on Twitch (idempotent)" do
      scope =
        user_scope_fixture(
          user_fixture(%{
            twitch: %{user_id: "9999", access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"}
          })
        )

      # Cache miss, fetch from Twitch API returns no subscriptions
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        response: %{
          "data" => [],
          "total" => 0,
          "total_cost" => 0,
          "max_total_cost" => 10_000
        },
        params: %{"user_id" => "9999"},
        status: 200
      )

      {:ok, result} = TwitchApi.unsubscribe(scope, "channel.follow")

      assert result == :no_subscription
    end

    test "cannot unsubscribe from an unknown Twitch event", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        request: "twitch_api/eventsub/create_event_subscription/request.json",
        response: "twitch_api/eventsub/create_event_subscription/response.json",
        status: 202
      )

      {:ok, _} = TwitchApi.subscribe(scope, "channel.follow")

      ApiMock.expect(
        TwitchApi,
        path: {:delete, "/helix/eventsub/subscriptions"},
        params: %{"id" => "26b1c993-bfcf-44d9-b876-379dacafe75a"},
        status: 404
      )

      {:ok, id} = TwitchApi.unsubscribe(scope, "channel.follow")

      assert id == "26b1c993-bfcf-44d9-b876-379dacafe75a"
    end
  end

  describe "cancel_all_subscriptions/1" do
    test "unsubscribe from all known subscriptions", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        response: "twitch_api/eventsub/get_event_subscriptions/response.json",
        params: %{"user_id" => "1234"},
        status: 200
      )

      ApiMock.expect(
        TwitchApi,
        path: {:delete, "/helix/eventsub/subscriptions"},
        params: %{"id" => "26b1c993-bfcf-44d9-b876-379dacafe75a"},
        status: 204
      )

      ApiMock.expect(
        TwitchApi,
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

    test "cannot unsubscribe from all known subscriptions in case API error", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        response: "twitch_api/eventsub/get_event_subscriptions/response.json",
        params: %{"user_id" => "1234"},
        status: 200
      )

      ApiMock.expect(
        TwitchApi,
        path: {:delete, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        params: %{"id" => "26b1c993-bfcf-44d9-b876-379dacafe75a"},
        status: 204
      )

      ApiMock.expect(
        TwitchApi,
        path: {:delete, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        params: %{"id" => "35016908-41ff-33ce-7879-61b8dfc2ee16"},
        status: 500
      )

      {:error, reason} = TwitchApi.cancel_all_subscriptions(scope)

      assert reason == "Cannot cancel all subscriptions"
    end
  end

  describe "resubscribe/2" do
    test "unsubscribes then subscribes to a Twitch event", %{scope: scope} do
      # First, create a subscription to have something in cache
      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        request: "twitch_api/eventsub/create_event_subscription/request.json",
        response: "twitch_api/eventsub/create_event_subscription/response.json",
        status: 202
      )

      {:ok, _} = TwitchApi.subscribe(scope, "channel.follow")

      # Now resubscribe: should unsubscribe then subscribe
      ApiMock.expect(
        TwitchApi,
        path: {:delete, "/helix/eventsub/subscriptions"},
        params: %{"id" => "26b1c993-bfcf-44d9-b876-379dacafe75a"},
        status: 204
      )

      ApiMock.expect(
        TwitchApi,
        path: {:post, "/helix/eventsub/subscriptions"},
        headers: [
          {"authorization", "Bearer token"},
          {"content-type", "application/json"}
        ],
        request: "twitch_api/eventsub/create_event_subscription/request.json",
        response: "twitch_api/eventsub/create_event_subscription/response.json",
        status: 202
      )

      {:ok, subscription} = TwitchApi.resubscribe(scope, "channel.follow")

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
  end
end
