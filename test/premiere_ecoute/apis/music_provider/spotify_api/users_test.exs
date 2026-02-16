defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.UsersTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi

  setup {Req.Test, :set_req_test_to_shared}
  setup {Req.Test, :verify_on_exit!}

  setup_all do
    token = UUID.uuid4()

    {:ok, %{token: token}}
  end

  describe "get_user_profile/1" do
    test "list playlist from an unique identifier", %{token: token} do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/me"},
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        response: "spotify_api/users/get_current_user_profile/response.json",
        status: 200
      )

      scope = user_scope_fixture(user_fixture(%{spotify: %{access_token: token}}))

      {:ok, profile} = SpotifyApi.get_user_profile(scope.user.spotify.access_token)

      assert profile == %{
               "display_name" => "lanfeust313",
               "country" => "FR",
               "email" => "maxime.janvier@gmail.com",
               "id" => "lanfeust313",
               "product" => "premium"
             }
    end
  end
end
