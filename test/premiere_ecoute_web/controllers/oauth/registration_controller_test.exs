defmodule PremiereEcouteWeb.Oauth.RegistrationControllerTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias PremiereEcouteWeb.Oauth.RegistrationController

  # AIDEV-NOTE: exercises only the response-shaping callbacks (RFC 7591 success/error bodies).
  # The `create/2` action itself delegates to Boruta.Openid.register_client/3, which needs the
  # boruta_clients table from `mix boruta.gen.migration` — add a full request/response
  # integration test once that migration has been generated and run.

  describe "client_registered/2" do
    test "returns the client credentials as RFC 7591 JSON", %{conn: conn} do
      client = %{
        id: "11111111-1111-1111-1111-111111111111",
        secret: "s3cr3t",
        inserted_at: ~U[2026-06-22 10:00:00Z],
        name: "claude.ai",
        redirect_uris: ["https://claude.ai/api/mcp/auth_callback"],
        supported_grant_types: ["authorization_code", "refresh_token"],
        token_endpoint_auth_methods: ["client_secret_post"]
      }

      conn = RegistrationController.client_registered(conn, client)

      assert conn.status == 201
      body = Jason.decode!(conn.resp_body)
      assert body["client_id"] == client.id
      assert body["client_secret"] == client.secret
      assert body["client_name"] == "claude.ai"
      assert body["redirect_uris"] == client.redirect_uris
      assert body["client_id_issued_at"] == DateTime.to_unix(client.inserted_at)
    end
  end

  describe "registration_failure/2" do
    test "returns an RFC 7591 invalid_client_metadata error", %{conn: conn} do
      changeset = %{errors: [redirect_uris: {"can't be blank", [validation: :required]}]}

      conn = RegistrationController.registration_failure(conn, changeset)

      assert conn.status == 400
      assert Jason.decode!(conn.resp_body) == %{
               "error" => "invalid_client_metadata",
               "error_description" => "Client registration parameters are invalid."
             }
    end
  end
end
