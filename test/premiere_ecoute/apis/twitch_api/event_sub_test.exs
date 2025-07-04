defmodule PremiereEcoute.Apis.TwitchApi.EventSubTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.TwitchApi

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
  end
end
