defmodule PremiereEcoute.PubSub do
  @moduledoc false

  @pubsub PremiereEcoute.PubSub

  alias PremiereEcoute.Accounts.User

  def subscribe(topic) when is_binary(topic), do: Phoenix.PubSub.subscribe(@pubsub, topic)
  def subscribe(topics) when is_list(topics), do: Enum.each(topics, &subscribe/1)
  def unsubscribe(topic) when is_binary(topic), do: Phoenix.PubSub.unsubscribe(@pubsub, topic)
  def unsubscribe(topics) when is_list(topics), do: Enum.each(topics, &unsubscribe/1)
  def broadcast(topic, message), do: Phoenix.PubSub.broadcast(@pubsub, topic, message)
  def info(%User{id: id}, message), do: broadcast("user:#{id}", {:info, message})
  def error(%User{id: id}, message), do: broadcast("user:#{id}", {:error, message})
end
