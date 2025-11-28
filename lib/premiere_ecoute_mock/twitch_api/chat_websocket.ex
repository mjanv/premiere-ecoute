defmodule PremiereEcouteMock.TwitchApi.ChatWebSocket do
  @moduledoc """
  Mock Twitch chat WebSocket handler.

  Implements WebSock behavior for mock chat connections, registers with ChatRegistry on init, receives chat messages and announcements via PubSub, and pushes JSON-encoded events to connected WebSocket clients.
  """

  require Logger

  @behaviour WebSock

  @doc """
  Initializes WebSocket connection and registers for chat messages.

  Logs connection establishment, subscribes to chat message registry for receiving messages, and initializes empty connection state.
  """
  @spec init(keyword()) :: {:ok, map()}
  def init(_opts) do
    Logger.info("Chat WebSocket connected")

    # Subscribe to chat messages
    Registry.register(PremiereEcouteMock.ChatRegistry, :chat_messages, self())

    {:ok, %{}}
  end

  @doc """
  Handles incoming WebSocket messages from client.

  Logs received messages for debugging and maintains connection state without processing client messages.
  """
  @spec handle_in({String.t() | binary(), keyword()}, map()) :: {:ok, map()}
  def handle_in({message, _opts}, state) do
    Logger.debug("Received WebSocket message: #{inspect(message)}")
    {:ok, state}
  end

  @doc """
  Handles chat messages and announcements from PubSub.

  Receives chat message or announcement events from registry, encodes them as JSON, and pushes to connected WebSocket client, or logs unhandled messages.
  """
  @spec handle_info(tuple() | term(), map()) :: {:push, {:text, String.t()}, map()} | {:ok, map()}
  def handle_info({:chat_message, message_data}, state) do
    json_message = Jason.encode!(message_data)
    {:push, {:text, json_message}, state}
  end

  def handle_info({:chat_announcement, announcement_data}, state) do
    json_message = Jason.encode!(announcement_data)
    {:push, {:text, json_message}, state}
  end

  def handle_info(message, state) do
    Logger.debug("Unhandled WebSocket info: #{inspect(message)}")
    {:ok, state}
  end

  @doc """
  Handles WebSocket connection termination.

  Logs disconnection with reason and performs cleanup when WebSocket connection is closed.
  """
  @spec terminate(term(), map()) :: :ok
  def terminate(reason, _state) do
    Logger.info("Chat WebSocket disconnected: #{inspect(reason)}")
    :ok
  end
end
