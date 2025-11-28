defmodule PremiereEcouteWeb.Plugs.TwitchHmacValidator do
  @moduledoc """
  Plug for validating Twitch EventSub HMAC signatures.

  Validates webhook requests from Twitch EventSub by verifying the HMAC signature in the request headers to ensure authenticity.

  ## Resources

  - [Twitch EventSub Documentation](https://dev.twitch.tv/docs/eventsub/)
  - [Verifying EventSub Signatures](https://dev.twitch.tv/docs/eventsub/handling-webhook-events/#verifying-the-event-message)
  """

  import Plug.Conn

  @secret Application.compile_env(:premiere_ecoute, :twitch_eventsub_secret)

  @doc false
  @spec init(any()) :: map()
  def init(_default), do: %{}

  @doc """
  Validates HMAC signature of incoming Twitch EventSub webhook requests.

  Reads the request body and verifies the HMAC signature using the message ID, timestamp, and secret. Assigns the validation result to the connection under :twitch_hmac key for downstream processing.
  """
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(%Plug.Conn{req_headers: req_headers} = conn, _opts) do
    with id when id != "" <- at(req_headers, "id"),
         {:ok, body, _} <- read_body(conn) do
      assign(conn, :twitch_hmac, hmac(req_headers, @secret, body))
    else
      _ -> conn
    end
  end

  @doc """
  Computes and verifies HMAC signature for Twitch EventSub message.

  Concatenates the message ID, timestamp, and body, computes the HMAC-SHA256 signature, and performs constant-time comparison with the signature from headers to prevent timing attacks.
  """
  @spec hmac(list(), binary(), binary()) :: boolean()
  def hmac(headers, secret, body) do
    (at(headers, "id") <> at(headers, "timestamp") <> body)
    |> then(fn payload -> :crypto.mac(:hmac, :sha256, secret, payload) end)
    |> Base.encode16(case: :lower)
    |> then(fn hmac -> "sha256=" <> hmac end)
    |> then(fn hmac -> Plug.Crypto.secure_compare(hmac, at(headers, "signature")) end)
  end

  @doc """
  Generates HMAC-SHA256 signature for a message with the given secret.

  Computes the HMAC signature and returns it in the format expected by Twitch EventSub (sha256= prefix with lowercase hex encoding).
  """
  @spec signature(binary(), binary()) :: binary()
  def signature(secret, message) do
    :crypto.mac(:hmac, :sha256, secret, message)
    |> Base.encode16(case: :lower)
    |> then(&("sha256=" <> &1))
  end

  @doc """
  Extracts Twitch EventSub message header value by key.

  Looks up the header with the twitch-eventsub-message- prefix and returns its value or empty string if not found.
  """
  @spec at(list(), binary()) :: binary()
  def at(headers, key) do
    headers
    |> List.keyfind("twitch-eventsub-message-" <> key, 0, {"", ""})
    |> elem(1)
  end
end
