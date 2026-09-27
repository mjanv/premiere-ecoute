defmodule PremiereEcouteWeb.Plugs.CanonicalHost do
  @moduledoc """
  Redirects requests made on another host to the canonical host, keeping path and query.

  Only enabled in development, where OAuth providers force two hosts: Twitch only accepts
  `http://localhost` redirect URLs and Spotify only accepts `http://127.0.0.1`. Bouncing the
  Spotify callback back to `localhost` lets it read the session cookie set at Twitch login.
  No-op when `config :premiere_ecoute, :canonical_host` is unset.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    case Keyword.get_lazy(opts, :host, fn -> Application.get_env(:premiere_ecoute, :canonical_host) end) do
      nil ->
        conn

      host when host == conn.host ->
        conn

      host ->
        location = %URI{
          scheme: to_string(conn.scheme),
          host: host,
          port: conn.port,
          path: conn.request_path,
          query: nilify(conn.query_string)
        }

        conn
        |> put_resp_header("location", URI.to_string(location))
        |> send_resp(302, "")
        |> halt()
    end
  end

  defp nilify(""), do: nil
  defp nilify(query), do: query
end
