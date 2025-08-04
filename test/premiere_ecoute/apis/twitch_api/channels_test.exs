defmodule PremiereEcoute.Apis.TwitchApi.ChannelsTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.TwitchApi

  setup do
    scope =
      user_scope_fixture(
        user_fixture(%{
          twitch: %{user_id: "141981764", access_token: "2gbdx6oar67tqtcmt49t3wpcgycthx"}
        })
      )

    streamer = user_fixture(%{email: "streamer@twitch.tv", twitch: %{user_id: "467189141"}})

    {:ok, %{scope: scope, streamer: streamer}}
  end

  describe "get_followed_channels/1" do
    test "gets a list of broadcasters that the user follows", %{scope: scope} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/channels/followed"},
        params: %{"user_id" => scope.user.twitch.user_id},
        response: "twitch_api/channels/followed/response1.json",
        status: 200
      )

      {:ok, channels} = TwitchApi.get_followed_channels(scope)

      assert channels == [
               %{
                 "broadcaster_id" => "11111",
                 "broadcaster_login" => "userloginname",
                 "broadcaster_name" => "UserDisplayName",
                 "followed_at" => "2022-05-24T22:22:08Z"
               },
               %{
                 "broadcaster_id" => "22222",
                 "broadcaster_login" => "streamqueen",
                 "broadcaster_name" => "StreamQueen",
                 "followed_at" => "2023-01-12T14:45:30Z"
               },
               %{
                 "broadcaster_id" => "33333",
                 "broadcaster_login" => "musicmania",
                 "broadcaster_name" => "MusicMania",
                 "followed_at" => "2022-09-18T18:10:00Z"
               }
             ]
    end
  end

  describe "get_followed_channel/2" do
    test "check that a user follows a specific broadcaster", %{scope: scope, streamer: streamer} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/channels/followed"},
        params: %{"user_id" => scope.user.twitch.user_id, "broadcaster_id" => streamer.twitch.user_id},
        response: "twitch_api/channels/followed/response2.json",
        status: 200
      )

      {:ok, channel} = TwitchApi.get_followed_channel(scope, streamer)

      assert channel == %{
               "broadcaster_id" => "654321",
               "broadcaster_login" => "basketweaver101",
               "broadcaster_name" => "BasketWeaver101",
               "followed_at" => "2022-05-24T22:22:08Z"
             }
    end

    test "check that a user does not follow a specific broadcaster", %{scope: scope, streamer: streamer} do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/channels/followed"},
        params: %{"user_id" => scope.user.twitch.user_id, "broadcaster_id" => streamer.twitch.user_id},
        response: "twitch_api/channels/followed/response3.json",
        status: 200
      )

      {:ok, channel} = TwitchApi.get_followed_channel(scope, streamer)

      assert channel == nil
    end
  end
end
