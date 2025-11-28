defmodule PremiereEcouteWeb.Plugs.RenewTokens do
  @moduledoc """
  Plug that automatically renews expired tokens for authenticated users.
  """

  import Plug.Conn

  alias PremiereEcoute.Accounts

  @doc false
  @spec init(any()) :: any()
  def init(default), do: default

  @doc """
  Renews expired OAuth tokens for authenticated users across all providers.

  Attempts token renewal for both Twitch and Spotify OAuth providers if the user is authenticated and their access tokens have expired. Updates the current scope assignments in the connection with refreshed tokens.
  """
  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    conn
    |> assign(:current_scope, Accounts.maybe_renew_token(conn, :twitch))
    |> assign(:current_scope, Accounts.maybe_renew_token(conn, :spotify))
  end
end
