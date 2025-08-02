defmodule PremiereEcoute.Apis.SpotifyApi.UsersTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Core.Cache

  setup_all do
    Cache.put(:tokens, :spotify, "token")

    :ok
  end

  describe "get_user_profile/1" do
    test "list playlist from an unique identifier" do
      ApiMock.expect(
        SpotifyApi,
        path: {:get, "/v1/me"},
        response: "spotify_api/users/get_current_user_profile/response.json",
        status: 200
      )

      scope = user_scope_fixture(user_fixture(%{spotify_access_token: "token"}))

      {:ok, profile} = SpotifyApi.get_user_profile(scope.user.spotify_access_token)

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
