defmodule PremiereEcouteWeb.Plugs.RenewTokens do
  @moduledoc """
  Plug that automatically renews expired Spotify tokens for authenticated users.
  """

  import Plug.Conn

  alias PremiereEcoute.Accounts.ApiToken

  def init(default), do: default

  def call(conn, _opts) do
    conn
    |> assign(:current_scope, ApiToken.maybe_renew_twitch_token(conn))
    |> assign(:current_scope, ApiToken.maybe_renew_spotify_token(conn))
  end
end
