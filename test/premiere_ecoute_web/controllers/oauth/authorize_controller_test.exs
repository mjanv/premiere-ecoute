defmodule PremiereEcouteWeb.Oauth.AuthorizeControllerTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias Boruta.Ecto.Admin

  setup do
    {:ok, client} =
      Admin.create_client(%{
        name: "claude.ai",
        redirect_uris: ["https://claude.ai/api/mcp/auth_callback"],
        supported_grant_types: ["authorization_code", "refresh_token"],
        pkce: true
      })

    %{client: client}
  end

  defp authorize_query(client) do
    %{
      "response_type" => "code",
      "client_id" => client.id,
      "redirect_uri" => "https://claude.ai/api/mcp/auth_callback",
      "scope" => "mcp",
      "state" => "xyz",
      "code_challenge" => "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      "code_challenge_method" => "S256"
    }
  end

  describe "GET /oauth/authorize" do
    test "redirects to home when the user is not authenticated", %{conn: conn, client: client} do
      conn = get(conn, ~p"/oauth/authorize?#{authorize_query(client)}")

      assert redirected_to(conn) == ~p"/"
    end

    test "shows the consent screen for a logged in user", %{conn: conn, client: client} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      conn = get(conn, ~p"/oauth/authorize?#{authorize_query(client)}")

      assert html = html_response(conn, 200)
      assert html =~ "claude.ai"
      assert html =~ "Approve"
      assert html =~ "Deny"
    end

    test "renders an error page for an unknown client", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn =
        get(
          conn,
          ~p"/oauth/authorize?#{%{"response_type" => "code", "client_id" => Ecto.UUID.generate(), "redirect_uri" => "https://example.com"}}"
        )

      assert conn.status in [400, 401]
    end
  end

  describe "POST /oauth/authorize" do
    test "approving redirects back to the client with an authorization code", %{conn: conn, client: client} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      query = authorize_query(client)

      conn = post(conn, ~p"/oauth/authorize?#{query}", %{"approved" => "true"})

      assert %{status: 302} = conn
      [location] = get_resp_header(conn, "location")
      assert location =~ "https://claude.ai/api/mcp/auth_callback"
      assert location =~ "code="
      assert location =~ "state=xyz"
    end

    test "denying redirects back to the client with access_denied", %{conn: conn, client: client} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      query = authorize_query(client)

      conn = post(conn, ~p"/oauth/authorize?#{query}", %{"approved" => "false"})

      assert %{status: 302} = conn
      [location] = get_resp_header(conn, "location")
      assert location =~ "https://claude.ai/api/mcp/auth_callback"
      assert location =~ "error=access_denied"
      assert location =~ "state=xyz"
    end
  end
end
