defmodule PremiereEcouteMock.TwitchApi.ChatWebSocket do
  @moduledoc false

  require Logger

  @behaviour WebSock

  def init(_opts) do
    Logger.info("Chat WebSocket connected")

    # Subscribe to chat messages
    Registry.register(PremiereEcouteMock.ChatRegistry, :chat_messages, self())

    {:ok, %{}}
  end

  def handle_in({message, _opts}, state) do
    Logger.debug("Received WebSocket message: #{inspect(message)}")
    {:ok, state}
  end

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

  def terminate(reason, _state) do
    Logger.info("Chat WebSocket disconnected: #{inspect(reason)}")
    :ok
  end
end
