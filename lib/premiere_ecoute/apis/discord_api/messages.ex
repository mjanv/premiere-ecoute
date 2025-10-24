defmodule PremiereEcoute.Apis.DiscordApi.Messages do
  @moduledoc """
  Discord Messages API

  Handles sending messages to Discord channels using the Discord API v10.
  Supports sending plain text messages to predefined channels or directly to specific channel IDs.
  """

  require Logger

  alias PremiereEcoute.Apis.DiscordApi

  @doc """
  Sends a plain text message to a predefined Discord channel.

  ## Parameters

    * `channel_key` - Atom key for the predefined channel (e.g., `:notifications`, `:announcements`)
    * `content` - Plain text message content to send

  ## Returns

    * `{:ok, message}` - Successfully sent message with Discord API response
    * `{:error, reason}` - Error sending message

  ## Examples

      iex> DiscordApi.Messages.send_message(:notifications, "Server is starting up")
      {:ok, %{"id" => "123456789", "content" => "Server is starting up", ...}}

      iex> DiscordApi.Messages.send_message(:invalid_channel, "Test")
      {:error, "Channel :invalid_channel not configured"}

  """
  @spec send_message(atom(), String.t()) :: {:ok, map()} | {:error, term()}
  def send_message(channel_key, content) when is_atom(channel_key) and is_binary(content) do
    case DiscordApi.channel(channel_key) do
      nil ->
        Logger.error("Discord channel #{inspect(channel_key)} not configured")
        {:error, "Channel #{inspect(channel_key)} not configured"}

      channel_id ->
        send_message_to_channel(channel_id, content)
    end
  end

  @doc """
  Sends a plain text message directly to a Discord channel by its ID.

  ## Parameters

    * `channel_id` - Discord channel ID (snowflake string)
    * `content` - Plain text message content to send

  ## Returns

    * `{:ok, message}` - Successfully sent message with Discord API response
    * `{:error, reason}` - Error sending message

  ## Examples

      iex> DiscordApi.Messages.send_message_to_channel("123456789", "Hello Discord!")
      {:ok, %{"id" => "987654321", "content" => "Hello Discord!", ...}}

  """
  @spec send_message_to_channel(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def send_message_to_channel(channel_id, content) when is_binary(channel_id) and is_binary(content) do
    # AIDEV-NOTE: Discord API endpoint for creating messages in a channel
    DiscordApi.api()
    |> DiscordApi.post(
      url: "/channels/#{channel_id}/messages",
      json: %{content: content}
    )
    |> DiscordApi.handle([200, 201], fn response ->
      Logger.info("Discord message sent to channel #{channel_id}")
      response
    end)
  end
end
