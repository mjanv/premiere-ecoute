defmodule PremiereEcouteMock.TwitchApi.Mock do
  @moduledoc """
  Mock Twitch API implementation for testing.

  Provides no-op implementations of Twitch API methods that log actions instead of making real API calls. Used in development and test environments.
  """

  require Logger

  @doc """
  Sends mock chat message with logging.

  Logs the message content instead of sending to actual Twitch chat, returning success for testing.
  """
  @spec send_chat_message(any(), String.t()) :: :ok
  def send_chat_message(_, message) do
    Logger.info("Chat message: #{message}")
    :ok
  end

  @doc """
  Sends mock chat announcement with color and logging.

  Logs the announcement message with specified color instead of sending to actual Twitch chat, returning success for testing.
  """
  @spec send_chat_announcement(any(), String.t(), String.t()) :: {:ok, String.t()}
  def send_chat_announcement(_, message, color) do
    Logger.info("Chat announcement: <#{color}>#{message}</#{color}>")
    {:ok, ""}
  end

  @doc """
  Returns empty EventSub subscriptions list for mock API.

  Simulates EventSub subscription queries without actual API calls, returning empty list for testing.
  """
  @spec get_event_subscriptions(any()) :: {:ok, list()}
  def get_event_subscriptions(_), do: {:ok, []}

  @doc """
  Creates mock EventSub subscription.

  Simulates EventSub subscription creation without actual API calls, returning empty map for testing.
  """
  @spec subscribe(any(), any()) :: {:ok, map()}
  def subscribe(_, _), do: {:ok, %{}}

  @doc """
  Deletes mock EventSub subscription.

  Simulates EventSub subscription deletion without actual API calls, returning empty string for testing.
  """
  @spec unsubscribe(any(), any()) :: {:ok, String.t()}
  def unsubscribe(_, _), do: {:ok, ""}

  @doc """
  Resubscribes to mock EventSub event type.

  Simulates EventSub resubscription without actual API calls, returning empty map for testing.
  """
  @spec resubscribe(any(), any()) :: {:ok, map()}
  def resubscribe(_, _), do: {:ok, %{}}

  @doc """
  Cancels all mock EventSub subscriptions.

  Simulates bulk EventSub subscription cancellation without actual API calls, returning empty list for testing.
  """
  @spec cancel_all_subscriptions(any()) :: {:ok, list()}
  def cancel_all_subscriptions(_), do: {:ok, []}

  @doc """
  Creates mock Twitch poll.

  Simulates Twitch poll creation without actual API calls, returning empty map for testing.
  """
  @spec create_poll(any(), any()) :: {:ok, map()}
  def create_poll(_, _), do: {:ok, %{}}

  @doc """
  Ends mock Twitch poll.

  Simulates Twitch poll termination without actual API calls, returning empty map for testing.
  """
  @spec end_poll(any(), any()) :: {:ok, map()}
  def end_poll(_, _), do: {:ok, %{}}

  @doc """
  Retrieves mock Twitch poll.

  Simulates Twitch poll retrieval without actual API calls, returning empty map for testing.
  """
  @spec get_poll(any(), any()) :: {:ok, map()}
  def get_poll(_, _), do: {:ok, %{}}
end
