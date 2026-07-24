defmodule PremiereEcouteWeb.Plugs.BuyMeACoffeeHmacValidator do
  @moduledoc """
  Plug for validating Buy Me a Coffee webhook HMAC signatures.

  Validates webhook requests from Buy Me a Coffee by verifying the `x-signature-sha256` header
  against an HMAC-SHA256 of the raw request body, computed with the webhook's signing secret.

  If `BUYMEACOFFEE_WEBHOOK_SECRET` isn't configured, requests are accepted unverified (a warning
  is logged once per request) so the app keeps working before the secret is provisioned — set the
  secret to enable verification.

  ## Resources

  - [Buy Me a Coffee webhooks](https://help.buymeacoffee.com/en/articles/15743173-how-to-setup-and-use-buy-me-a-coffee-webhooks)
  """

  import Plug.Conn

  require Logger

  @doc false
  @spec init(any()) :: map()
  def init(_default), do: %{}

  @doc """
  Validates the HMAC signature of an incoming Buy Me a Coffee webhook request.

  Reads the raw request body and verifies it against the `x-signature-sha256` header. Assigns
  the validation result to the connection under the :buymeacoffee_hmac key for downstream
  processing.
  """
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  if Application.compile_env(:premiere_ecoute, :environment) == :dev do
    def call(conn, _opts), do: assign(conn, :buymeacoffee_hmac, true)
  else
    def call(%Plug.Conn{request_path: "/webhooks/buymeacoffee", req_headers: req_headers} = conn, _opts) do
      case Application.get_env(:premiere_ecoute, :buymeacoffee_webhook_secret) do
        nil ->
          log_unconfigured()
          assign(conn, :buymeacoffee_hmac, true)

        secret ->
          case read_body(conn) do
            {:ok, body, _} -> assign(conn, :buymeacoffee_hmac, hmac(req_headers, secret, body))
            _ -> assign(conn, :buymeacoffee_hmac, false)
          end
      end
    end

    def call(conn, _opts), do: conn
  end

  @doc false
  @spec log_unconfigured() :: :ok
  def log_unconfigured do
    Logger.warning("BuyMeACoffee webhook accepted unverified: no signing secret configured")
  end

  @doc """
  Computes and verifies the HMAC-SHA256 signature for a Buy Me a Coffee webhook payload.

  Hashes the raw body with the signing secret and performs a constant-time comparison against
  the `x-signature-sha256` header to prevent timing attacks.
  """
  @spec hmac(list(), binary(), binary()) :: boolean()
  def hmac(headers, secret, body) do
    expected = signature(secret, body)
    received = at(headers, "x-signature-sha256")

    received != "" && Plug.Crypto.secure_compare(expected, received)
  end

  @doc """
  Generates the HMAC-SHA256 signature for a message with the given secret.

  Computes the HMAC signature in the format expected by Buy Me a Coffee (lowercase hex, no
  prefix).
  """
  @spec signature(binary(), binary()) :: binary()
  def signature(secret, message) do
    :crypto.mac(:hmac, :sha256, secret, message)
    |> Base.encode16(case: :lower)
  end

  defp at(headers, key) do
    headers
    |> List.keyfind(key, 0, {"", ""})
    |> elem(1)
  end
end
