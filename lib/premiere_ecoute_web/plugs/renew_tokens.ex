defmodule PremiereEcouteWeb.Plugs.RenewTokens do
  @moduledoc """
  Plug that automatically renews expired Spotify tokens for authenticated users.
  """

  import Plug.Conn

  alias PremiereEcoute.Accounts.Services.TokenRenewal

  def init(default), do: default

  def call(conn, _opts) do
    conn
    # |> assign(:current_scope, TokenRenewal.maybe_renew_token(conn, :twitch))
    |> assign(:current_scope, TokenRenewal.maybe_renew_token(conn, :spotify))
  end
end
