defmodule PremiereEcoute.Accounts.ApiToken do
  @moduledoc """
  Plug that automatically renews expired Spotify tokens for authenticated users.
  """

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.TwitchApi

  def maybe_renew_twitch_token(conn) do
    with %Scope{user: %User{twitch_expires_at: expires_at, twitch_refresh_token: refresh_token} = user} = scope <-
           conn.assigns[:current_scope],
         true <- token_expired?(expires_at),
         {:ok, tokens} <- TwitchApi.renew_token(refresh_token),
         {:ok, user} <- User.update_twitch_tokens(user, tokens) do
      %{scope | user: user}
    else
      {:error, reason} ->
        Logger.error("Failed to renew Spotify token: #{inspect(reason)}")
        conn.assigns[:current_scope]

      _ ->
        conn.assigns[:current_scope]
    end
  end

  def maybe_renew_spotify_token(conn) do
    with %{user: %{spotify_expires_at: expires_at, spotify_refresh_token: refresh_token} = user} = scope <-
           conn.assigns[:current_scope],
         true <- token_expired?(expires_at),
         {:ok, tokens} <- SpotifyApi.renew_token(refresh_token),
         {:ok, user} <- User.update_spotify_tokens(user, tokens) do
      %{scope | user: user}
    else
      {:error, reason} ->
        Logger.error("Failed to renew Twitch token: #{inspect(reason)}")
        conn.assigns[:current_scope]

      _ ->
        conn.assigns[:current_scope]
    end
  end

  defp token_expired?(nil), do: false
  defp token_expired?(at), do: DateTime.compare(DateTime.utc_now(), DateTime.add(at, -300, :second)) == :gt
end
