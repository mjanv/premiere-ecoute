defmodule PremiereEcouteWeb.Plugs.RenewTokens do
  @moduledoc """
  Plug that automatically renews expired tokens for authenticated users.
  """

  import Plug.Conn

  alias PremiereEcoute.Accounts

  def init(default), do: default

  def call(conn, _opts) do
    conn
    |> assign(:current_scope, Accounts.maybe_renew_token(conn, :twitch))
    |> assign(:current_scope, Accounts.maybe_renew_token(conn, :spotify))
  end
end
