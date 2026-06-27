defmodule PremiereEcouteWeb.Oauth.RegistrationControllerTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias Boruta.Ecto.Admin
  alias Boruta.Oauth.Client
  alias PremiereEcouteWeb.Oauth.RegistrationController

  describe "POST /oauth/register" do
    test "registers a new client and returns its credentials as RFC 7591 JSON", %{conn: conn} do
      conn =
        post(conn, ~p"/oauth/register", %{
          "redirect_uris" => ["https://claude.ai/api/mcp/auth_callback"],
          "client_name" => "claude.ai",
          "grant_types" => ["authorization_code", "refresh_token"],
          "token_endpoint_auth_method" => "none"
        })

      assert %{"client_id" => client_id, "client_secret" => client_secret} = json_response(conn, 201)
      assert is_binary(client_id)
      assert is_binary(client_secret)

      body = json_response(conn, 201)
      assert body["redirect_uris"] == ["https://claude.ai/api/mcp/auth_callback"]
      assert body["client_name"] == "claude.ai"
      assert body["grant_types"] == ["authorization_code", "refresh_token"]
      assert is_integer(body["client_id_issued_at"])

      stored = Admin.get_client!(client_id)
      refute stored.confidential
      assert stored.pkce
    end

    test "rejects registration with invalid metadata", %{conn: conn} do
      conn =
        post(conn, ~p"/oauth/register", %{
          "redirect_uris" => ["https://claude.ai/api/mcp/auth_callback"],
          "supported_grant_types" => ["not_a_real_grant_type"]
        })

      assert json_response(conn, 400)["error"] == "invalid_client_metadata"
    end
  end

  describe "client_registered/2" do
    test "returns the client credentials as RFC 7591 JSON", %{conn: conn} do
      client = %Client{
        id: "11111111-1111-1111-1111-111111111111",
        secret: "s3cr3t",
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
      assert is_integer(body["client_id_issued_at"])
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
