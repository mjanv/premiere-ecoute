defmodule PremiereEcouteWeb.Plugs.RenewTokens do
  @moduledoc """
  Plug that automatically renews expired Spotify tokens for authenticated users.
  """

  import Plug.Conn

  alias PremiereEcoute.Accounts.Services.TokenRenewal

  def init(default), do: default

  def call(conn, _opts) do
    conn
    |> assign(:current_scope, TokenRenewal.maybe_renew_twitch_token(conn))
    |> assign(:current_scope, TokenRenewal.maybe_renew_spotify_token(conn))
  end
end
