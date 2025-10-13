defmodule PremiereEcouteWeb.Plugs.TwitchExtensionAuth do
  @moduledoc """
  Plug for authenticating Twitch Extension JWT tokens.

  Validates JWT tokens sent by Twitch extensions and extracts user information.
  Supports both authenticated users and anonymous viewers.
  """

  import Plug.Conn

  require Logger

  @doc false
  def init(opts), do: opts

  @doc """
  Validates the Twitch extension JWT token and assigns user context.

  The JWT token contains:
  - user_id: Twitch user ID (for authenticated users) or anonymous ID
  - channel_id: Broadcaster's Twitch channel ID  
  - role: "broadcaster", "moderator", or "viewer"
  - exp: Token expiration
  """
  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        verify_extension_token(conn, token)

      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Missing authorization header"})
        |> halt()
    end
  end

  defp verify_extension_token(conn, token) do
    # Get the extension secret from config
    extension_secret = get_extension_secret()

    case verify_jwt(token, extension_secret) do
      {:ok, claims} ->
        assign_extension_context(conn, claims)

      {:error, reason} ->
        Logger.warning("Invalid extension token: #{inspect(reason)}")

        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Invalid token"})
        |> halt()
    end
  end

  defp verify_jwt(token, secret) do
    # AIDEV-NOTE: JWT verification using JOSE library for Twitch extension tokens
    try do
      case JOSE.JWT.verify(JOSE.JWS.expand(token), JOSE.JWK.from_oct(secret)) do
        {true, jwt, _jws} ->
          claims = JOSE.JWT.to_map(jwt) |> elem(1)

          # Check token expiration
          now = System.system_time(:second)
          exp = Map.get(claims, "exp", 0)

          if exp > now do
            {:ok, claims}
          else
            {:error, :expired}
          end

        {false, _, _} ->
          {:error, :invalid_signature}
      end
    rescue
      error ->
        {:error, {:decode_error, error}}
    end
  end

  defp assign_extension_context(conn, claims) do
    user_id = Map.get(claims, "user_id")
    channel_id = Map.get(claims, "channel_id")
    role = Map.get(claims, "role", "viewer")

    # Determine if user is authenticated (has non-anonymous user_id)
    is_authenticated = user_id && !String.starts_with?(user_id, "A")

    extension_context = %{
      user_id: user_id,
      channel_id: channel_id,
      role: role,
      is_authenticated: is_authenticated,
      claims: claims
    }

    assign(conn, :extension_context, extension_context)
  end

  defp get_extension_secret do
    Application.get_env(:premiere_ecoute, :twitch_extension_secret) ||
      raise "TWITCH_EXTENSION_SECRET environment variable not set"
  end
end
