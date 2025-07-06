defmodule PremiereEcoute.Apis.TwitchApi.Chat do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.TwitchApi

  def send_chat_message(%Scope{user: %{twitch_user_id: user_id}}, message) do
    TwitchApi.api(:helix)
    |> Req.post(
      url: "/chat/messages",
      json: %{
        broadcaster_id: user_id,
        sender_id: user_id,
        message: message,
        for_source_only: true
      }
    )
    |> case do
      {:ok, %{status: 200, body: %{"data" => [message]}}} ->
        {:ok, message}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitch chat message send failed: #{status} - #{inspect(body)}")
        {:error, "Failed to send chat message"}

      {:error, reason} ->
        Logger.error("Twitch chat message request failed: #{inspect(reason)}")
        {:error, "Network error sending chat message"}
    end
  end

  def send_chat_announcement(
        %Scope{user: %{twitch_user_id: user_id, twitch_access_token: token}},
        message,
        color \\ "purple"
      ) do
    TwitchApi.api(:helix, token)
    |> Req.post(
      url: "/chat/announcements",
      params: %{
        broadcaster_id: user_id,
        moderator_id: user_id
      },
      json: %{
        message: message,
        color: color
      }
    )
    |> case do
      {:ok, %{status: 204}} ->
        {:ok, message}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitch chat announcement send failed: #{status} - #{inspect(body)}")
        {:error, "Failed to send chat announcement"}

      {:error, reason} ->
        Logger.error("Twitch chat announcement request failed: #{inspect(reason)}")
        {:error, "Network error sending chat announcement"}
    end
  end
end
