defmodule PremiereEcouteMock.TwitchApi.Mock do
  @moduledoc """
  Mock Twitch API implementation for testing.

  Provides no-op implementations of Twitch API methods that log actions instead of making real API calls. Used in development and test environments.
  """

  require Logger

  def send_chat_message(_, message) do
    Logger.info("Chat message: #{message}")
    :ok
  end

  def send_chat_announcement(_, message, color) do
    Logger.info("Chat announcement: <#{color}>#{message}</#{color}>")
    {:ok, ""}
  end

  def get_event_subscriptions(_), do: {:ok, []}
  def subscribe(_, _), do: {:ok, %{}}
  def unsubscribe(_, _), do: {:ok, ""}
  def cancel_all_subscriptions(_), do: {:ok, []}

  def create_poll(_, _), do: {:ok, %{}}
  def end_poll(_, _), do: {:ok, %{}}
  def get_poll(_, _), do: {:ok, %{}}
end
