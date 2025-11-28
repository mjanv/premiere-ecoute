defmodule PremiereEcoute.PubSub do
  @moduledoc """
  PubSub utilities.

  Provides convenience functions for subscribing, unsubscribing, broadcasting messages, and sending user notifications through Phoenix PubSub.
  """

  @pubsub PremiereEcoute.PubSub

  alias PremiereEcoute.Accounts.User

  @doc """
  Subscribes to PubSub topic or topics.

  Accepts single topic string or list of topics. Registers current process to receive messages published to topics.
  """
  @spec subscribe(String.t() | list(String.t())) :: :ok | {:error, term()}
  def subscribe(topic) when is_binary(topic), do: Phoenix.PubSub.subscribe(@pubsub, topic)
  def subscribe(topics) when is_list(topics), do: Enum.each(topics, &subscribe/1)

  @doc """
  Unsubscribes from PubSub topic or topics.

  Accepts single topic string or list of topics. Removes current process from receiving messages published to topics.
  """
  @spec unsubscribe(String.t() | list(String.t())) :: :ok | {:error, term()}
  def unsubscribe(topic) when is_binary(topic), do: Phoenix.PubSub.unsubscribe(@pubsub, topic)
  def unsubscribe(topics) when is_list(topics), do: Enum.each(topics, &unsubscribe/1)

  @doc """
  Broadcasts message to all subscribers of topic.

  Sends message to all processes subscribed to the specified topic.
  """
  @spec broadcast(String.t(), term()) :: :ok | {:error, term()}
  def broadcast(topic, message), do: Phoenix.PubSub.broadcast(@pubsub, topic, message)

  @doc """
  Sends info notification to user's personal topic.

  Broadcasts info message tuple to user-specific topic for display in UI.
  """
  @spec info(User.t(), String.t()) :: :ok | {:error, term()}
  def info(%User{id: id}, message), do: broadcast("user:#{id}", {:info, message})

  @doc """
  Sends error notification to user's personal topic.

  Broadcasts error message tuple to user-specific topic for display in UI.
  """
  @spec error(User.t(), String.t()) :: :ok | {:error, term()}
  def error(%User{id: id}, message), do: broadcast("user:#{id}", {:error, message})
end
