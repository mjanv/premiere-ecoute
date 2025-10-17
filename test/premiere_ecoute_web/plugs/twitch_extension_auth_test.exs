defmodule PremiereEcouteWeb.Plugs.TwitchExtensionAuthTest do
  use PremiereEcouteWeb.ConnCase, async: true

  alias PremiereEcouteWeb.Plugs.TwitchExtensionAuth

  @test_secret "test_secret_key_for_twitch_extension"
  @test_secret_base64 Base.encode64(@test_secret)

  setup do
    # Store original config value
    original_secret = Application.get_env(:premiere_ecoute, :twitch_extension_secret)

    Application.put_env(:premiere_ecoute, :twitch_extension_secret, @test_secret_base64)

    on_exit(fn ->
      # Restore original value
      if original_secret do
        Application.put_env(:premiere_ecoute, :twitch_extension_secret, original_secret)
      else
        Application.delete_env(:premiere_ecoute, :twitch_extension_secret)
      end
    end)

    :ok
  end

  describe "call/2 with valid authenticated JWT" do
    test "assigns extension_context with user claims", %{conn: conn} do
      claims = %{
        "exp" => System.system_time(:second) + 3600,
        "user_id" => "123456789",
        "channel_id" => "987654321",
        "role" => "viewer"
      }

      token = generate_jwt(claims, @test_secret)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> TwitchExtensionAuth.call([])

      refute conn.halted
      context = conn.assigns.extension_context
      assert context.user_id == "123456789"
      assert context.channel_id == "987654321"
      assert context.role == "viewer"
      assert context.is_authenticated == true
      assert is_map(context.claims)
    end

    test "handles broadcaster role correctly", %{conn: conn} do
      claims = %{
        "exp" => System.system_time(:second) + 3600,
        "user_id" => "123456789",
        "channel_id" => "123456789",
        "role" => "broadcaster"
      }

      token = generate_jwt(claims, @test_secret)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> TwitchExtensionAuth.call([])

      assert conn.assigns.extension_context.role == "broadcaster"
    end
  end

  describe "call/2 with valid anonymous JWT" do
    test "assigns extension_context for anonymous user (ID starts with 'A')", %{conn: conn} do
      claims = %{
        "exp" => System.system_time(:second) + 3600,
        "user_id" => "A123456789",
        "channel_id" => "987654321",
        "role" => "viewer"
      }

      token = generate_jwt(claims, @test_secret)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> TwitchExtensionAuth.call([])

      refute conn.halted
      context = conn.assigns.extension_context
      assert context.user_id == "A123456789"
      assert context.channel_id == "987654321"
      assert context.role == "viewer"
      assert context.is_authenticated == false
      assert is_map(context.claims)
    end
  end

  describe "call/2 with invalid signature" do
    test "returns 401 and halts connection", %{conn: conn} do
      claims = %{
        "exp" => System.system_time(:second) + 3600,
        "user_id" => "123456789",
        "channel_id" => "987654321",
        "role" => "viewer"
      }

      token = generate_jwt(claims, "wrong_secret")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> TwitchExtensionAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert json_response(conn, 401) == %{"error" => "Invalid token"}
    end
  end

  describe "call/2 with expired token" do
    test "returns 401 for token expired 1 hour ago", %{conn: conn} do
      claims = %{
        # Expired 1 hour ago
        "exp" => System.system_time(:second) - 3600,
        "user_id" => "123456789",
        "channel_id" => "987654321",
        "role" => "viewer"
      }

      token = generate_jwt(claims, @test_secret)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> TwitchExtensionAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert json_response(conn, 401) == %{"error" => "Invalid token"}
    end

    test "returns 401 for token expired 10 seconds ago", %{conn: conn} do
      claims = %{
        "exp" => System.system_time(:second) - 10,
        "user_id" => "123456789",
        "channel_id" => "987654321",
        "role" => "viewer"
      }

      token = generate_jwt(claims, @test_secret)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> TwitchExtensionAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert json_response(conn, 401) == %{"error" => "Invalid token"}
    end

    test "accepts token expired 3 seconds ago (within leeway window)", %{conn: conn} do
      claims = %{
        "exp" => System.system_time(:second) - 3,
        "user_id" => "123456789",
        "channel_id" => "987654321",
        "role" => "viewer"
      }

      token = generate_jwt(claims, @test_secret)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> TwitchExtensionAuth.call([])

      refute conn.halted
      assert conn.assigns.extension_context.user_id == "123456789"
    end
  end

  describe "call/2 with missing authorization" do
    test "returns 401 when Authorization header is missing", %{conn: conn} do
      conn = TwitchExtensionAuth.call(conn, [])

      assert conn.halted
      assert conn.status == 401
      assert json_response(conn, 401) == %{"error" => "Missing authorization header"}
    end

    test "returns 401 when Authorization header is empty", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "")
        |> TwitchExtensionAuth.call([])

      assert conn.halted
      assert conn.status == 401
      assert json_response(conn, 401) == %{"error" => "Missing authorization header"}
    end
  end

  describe "call/2 with malformed tokens" do
    test "returns 401 for malformed Bearer token format", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "NotBearer token123")
        |> TwitchExtensionAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 for Bearer without token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer ")
        |> TwitchExtensionAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 for random string as token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not.a.valid.jwt")
        |> TwitchExtensionAuth.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end

  describe "call/2 with missing claims" do
    test "handles token with missing user_id claim", %{conn: conn} do
      claims = %{
        "exp" => System.system_time(:second) + 3600,
        "channel_id" => "987654321",
        "role" => "viewer"
      }

      token = generate_jwt(claims, @test_secret)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> TwitchExtensionAuth.call([])

      refute conn.halted
      assert conn.assigns.extension_context.user_id == nil
      assert conn.assigns.extension_context.channel_id == "987654321"
    end

    test "handles token with missing role claim (defaults to viewer)", %{conn: conn} do
      claims = %{
        "exp" => System.system_time(:second) + 3600,
        "user_id" => "123456789",
        "channel_id" => "987654321"
      }

      token = generate_jwt(claims, @test_secret)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> TwitchExtensionAuth.call([])

      refute conn.halted
      assert conn.assigns.extension_context.role == "viewer"
    end
  end

  defp generate_jwt(claims, secret) do
    jwk = JOSE.JWK.from_oct(secret)
    jws = %{"alg" => "HS256"}
    jwt = JOSE.JWT.from_map(claims)

    {_jws_map, jws_signed} = JOSE.JWT.sign(jwk, jws, jwt)
    {_type, token} = JOSE.JWS.compact(jws_signed)
    token
  end
end
