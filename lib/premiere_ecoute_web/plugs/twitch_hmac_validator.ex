defmodule PremiereEcouteWeb.Plugs.TwitchHmacValidator do
  @moduledoc false

  import Plug.Conn

  @secret Application.compile_env(:premiere_ecoute, :twitch_eventsub_secret)

  def init(_default), do: %{}

  def call(%Plug.Conn{req_headers: req_headers} = conn, _opts) do
    with id when id != "" <- at(req_headers, "id"),
         {:ok, body, _} <- read_body(conn) do
      assign(conn, :twitch_hmac, hmac(req_headers, @secret, body))
    else
      _ -> conn
    end
  end

  def hmac(headers, secret, body) do
    (at(headers, "id") <> at(headers, "timestamp") <> body)
    |> then(fn payload -> :crypto.mac(:hmac, :sha256, secret, payload) end)
    |> Base.encode16(case: :lower)
    |> then(fn hmac -> "sha256=" <> hmac end)
    |> then(fn hmac -> Plug.Crypto.secure_compare(hmac, at(headers, "signature")) end)
  end

  def signature(secret, message) do
    :crypto.mac(:hmac, :sha256, secret, message)
    |> Base.encode16(case: :lower)
    |> then(&("sha256=" <> &1))
  end

  def at(headers, key) do
    headers
    |> List.keyfind("twitch-eventsub-message-" <> key, 0, {"", ""})
    |> elem(1)
  end
end
