defmodule PremiereEcoute.Apis.TidalApiTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.ApiMock
  alias PremiereEcoute.Apis.TidalApi

  describe "client_credentials/0" do
    test "can retrieve access token using client credentials flow" do
      client_id = Application.get_env(:premiere_ecoute, :tidal_client_id)
      client_secret = Application.get_env(:premiere_ecoute, :tidal_client_secret)
      auth_header = Base.encode64("#{client_id}:#{client_secret}")

      ApiMock.expect(
        TidalApi,
        path: {:post, "/v1/oauth2/token"},
        headers: [
          {"authorization", "Basic #{auth_header}"},
          {"content-type", "application/x-www-form-urlencoded"}
        ],
        response: "tidal_api/accounts/client_credentials/response.json",
        status: 200
      )

      {:ok, response} = TidalApi.client_credentials()

      assert %{
        "access_token" => "xHhiYE85rkDfPt7wLOyq3MqN2gKmB9n5WvJcP3sA",
        "token_type" => "Bearer",
        "expires_in" => 86400,
        "scope" => "openapi"
      } = response
    end
  end
end
