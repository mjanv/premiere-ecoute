defmodule PremiereEcoute.Apis.TwitchApi.UsersTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.TwitchApi

  describe "get_user_profile/1" do
    test "can get information about one Twitch user" do
      ApiMock.expect(
        TwitchApi,
        path: {:get, "/helix/users"},
        response: "twitch_api/users/get_users/response.json",
        status: 200
      )

      scope = user_scope_fixture(user_fixture(%{twitch: %{access_token: "token"}}))

      {:ok, user} = TwitchApi.get_user_profile(scope.user.twitch.access_token)

      assert user == %{
               "broadcaster_type" => "partner",
               "created_at" => "2016-12-14T20:32:28Z",
               "description" =>
                 "Supporting third-party developers building Twitch integrations from chatbots to game integrations.",
               "display_name" => "TwitchDev",
               "email" => "not-real@email.com",
               "id" => "141981764",
               "login" => "twitchdev",
               "offline_image_url" =>
                 "https://static-cdn.jtvnw.net/jtv_user_pictures/3f13ab61-ec78-4fe6-8481-8682cb3b0ac2-channel_offline_image-1920x1080.png",
               "profile_image_url" =>
                 "https://static-cdn.jtvnw.net/jtv_user_pictures/8a6381c7-d0c0-4576-b179-38bd5ce1d6af-profile_image-300x300.png",
               "type" => "",
               "view_count" => 5_980_557
             }
    end
  end
end
