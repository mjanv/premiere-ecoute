defmodule PremiereEcouteWeb.Plugs.RenewTokens do
  @moduledoc """
  Plug that automatically renews expired Spotify tokens for authenticated users.
  """

  import Plug.Conn

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.TwitchApi

  def init(default), do: default

  def call(conn, _opts) do
    conn
    |> maybe_renew_twitch_token()
    |> maybe_renew_spotify_token()
  end

  defp maybe_renew_twitch_token(conn) do
    with %{user: %{twitch_expires_at: expires_at, twitch_refresh_token: refresh_token} = user} <-
           conn.assigns[:current_scope],
         true <- token_expired?(expires_at),
         {:ok, tokens} <- TwitchApi.renew_token(refresh_token),
         {:ok, user} <- Accounts.User.update_twitch_tokens(user, tokens) do
      assign(conn, :current_scope, %{conn.assigns.current_scope | user: user})
    else
      {:error, reason} ->
        Logger.error("Failed to renew Spotify token: #{inspect(reason)}")
        conn

      _ ->
        conn
    end
  end

  defp maybe_renew_spotify_token(conn) do
    with %{user: %{spotify_expires_at: expires_at, spotify_refresh_token: refresh_token} = user} <-
           conn.assigns[:current_scope],
         true <- token_expired?(expires_at),
         {:ok, tokens} <- SpotifyApi.renew_token(refresh_token),
         {:ok, user} <- Accounts.User.update_spotify_tokens(user, tokens) do
      assign(conn, :current_scope, %{conn.assigns.current_scope | user: user})
    else
      {:error, reason} ->
        Logger.error("Failed to renew Twitch token: #{inspect(reason)}")
        conn

      _ ->
        conn
    end
  end

  defp token_expired?(nil), do: false
  # DateTime.compare(DateTime.utc_now(), DateTime.add(at, -300, :second)) == :gt
  defp token_expired?(_at), do: true
end
