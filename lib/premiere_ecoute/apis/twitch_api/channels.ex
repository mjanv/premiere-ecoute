defmodule PremiereEcoute.Apis.TwitchApi.Channels do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.TwitchApi

  def get_followed_channels(%Scope{user: %{twitch_user_id: user_id, twitch_access_token: token}}) do
    TwitchApi.api(:helix, token)
    |> Req.get(url: "/channels/followed", params: %{user_id: user_id})
    |> case do
      {:ok, %{status: 200, body: %{"data" => data}}} ->
        {:ok, data}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitch followed channels retrieval failed: #{status} - #{inspect(body)}")
        {:error, "Failed to fetch followed channels"}

      {:error, reason} ->
        Logger.error("Twitch followed channels request failed: #{inspect(reason)}")
        {:error, "Network error fetching channels"}
    end
  end

  def get_followed_channel(%Scope{user: %{twitch_user_id: user_id, twitch_access_token: token}}, %User{
        twitch_user_id: streamer_id
      }) do
    TwitchApi.api(:helix, token)
    |> Req.get(url: "/channels/followed", params: %{user_id: user_id, broadcaster_id: streamer_id})
    |> case do
      {:ok, %{status: 200, body: %{"data" => [channel]}}} ->
        {:ok, channel}

      {:ok, %{status: 200, body: %{"data" => []}}} ->
        {:ok, nil}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitch followed channels retrieval failed: #{status} - #{inspect(body)}")
        {:error, "Failed to fetch followed channels"}

      {:error, reason} ->
        Logger.error("Twitch followed channels request failed: #{inspect(reason)}")
        {:error, "Network error fetching channels"}
    end
  end
end
