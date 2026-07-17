defmodule PremiereEcouteWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Sets a Content-Security-Policy header on browser responses.

  The policy is derived from the external origins the frontend actually uses:

    * Scripts   — self, Alpine.js (unpkg), PostHog, the YouTube IFrame API + its player host (ytimg)
    * Frames    — YouTube and Spotify embeds
    * Connect   — self (incl. the LiveView websocket) and PostHog ingestion
    * Images    — self, data: URIs, and YouTube/Spotify thumbnail hosts
    * Fonts/CSS — self-hosted

  `script-src` and `style-src` keep `'unsafe-inline'`: the layout ships inline `<script>` blocks
  (PostHog init, theme) and templates use inline `style=` attributes for the always-dark chrome.
  The hard wins here are `object-src 'none'`, `base-uri 'self'`, `frame-ancestors`, and
  `form-action 'self'`, plus restricting script/frame/connect/img to a known host allowlist.

  Set `csp: :report_only` in the app env to emit `Content-Security-Policy-Report-Only` instead of
  enforcing — useful when tightening the policy further (e.g. moving to nonces).
  """

  import Plug.Conn

  @policy [
            "default-src 'self'",
            "script-src 'self' 'unsafe-inline' https://unpkg.com https://eu.i.posthog.com https://www.youtube.com https://s.ytimg.com",
            "style-src 'self' 'unsafe-inline'",
            "img-src 'self' data: https://i.ytimg.com https://i.scdn.co",
            "font-src 'self'",
            "connect-src 'self' https://eu.i.posthog.com",
            "frame-src https://www.youtube.com https://www.youtube-nocookie.com https://open.spotify.com",
            "media-src 'self' blob:",
            "object-src 'none'",
            "base-uri 'self'",
            "form-action 'self'",
            "frame-ancestors 'self'"
          ]
          |> Enum.join("; ")

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    header =
      case Application.get_env(:premiere_ecoute, :csp) do
        :report_only -> "content-security-policy-report-only"
        _ -> "content-security-policy"
      end

    put_resp_header(conn, header, @policy)
  end
end
