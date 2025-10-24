defmodule PremiereEcoute.Apis.DiscordApi do
  @moduledoc """
  # Discord API Client

  Central client for Discord API integration providing messaging capabilities for sending notifications
  and announcements to predefined Discord channels. This module acts as the main interface for all
  Discord-related operations, delegating to specialized submodules for specific API domains while
  handling common concerns like authentication, request configuration, and telemetry.

  ## Messages

  Provides message sending capabilities to Discord channels using bot token authentication. Messages
  are sent to predefined channels configured in the application settings. Supports plain text messages
  for notifications and announcements.

  ## Authentication

  Uses Discord Bot token authentication with the `Authorization: Bot <token>` header. The bot token
  is configured via environment variables and loaded at runtime for security.

  ## Channel Configuration

  Channel IDs are predefined in the application configuration (config/config.exs) under the discord
  channels section. This allows for easy management of target channels without code changes.
  """

  use PremiereEcouteCore.Api, api: :discord

  defmodule Behaviour do
    @moduledoc """
    Discord API Behaviour
    """

    # Messages
    @callback send_message(channel_key :: atom(), content :: String.t()) ::
                {:ok, map()} | {:error, term()}
    @callback send_message_to_channel(channel_id :: String.t(), content :: String.t()) ::
                {:ok, map()} | {:error, term()}
  end

  @spec api :: Req.Request.t()
  def api do
    token = Application.get_env(:premiere_ecoute, :discord_bot_token)

    [
      base_url: url(:api),
      headers: [
        {"Authorization", "Bot #{token}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> new()
  end

  # AIDEV-NOTE: helper to retrieve predefined channel IDs from config
  @spec channel(atom()) :: String.t() | nil
  def channel(channel_key) do
    get_in(env(), [:channels, channel_key])
  end
  
  @spec client_credentials() :: {:ok, %{String.t() => String.t() | integer()}}
  def client_credentials, do: {:ok, %{"access_token" => "", "expires_in" => 0}}

  # Messages
  defdelegate send_message(channel_key, content), to: __MODULE__.Messages
  defdelegate send_message_to_channel(channel_id, content), to: __MODULE__.Messages
end
