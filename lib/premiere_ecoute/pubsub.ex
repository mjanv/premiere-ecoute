defmodule PremiereEcoute.PubSub do
  @moduledoc false

  @pubsub PremiereEcoute.PubSub

  def subscribe([]), do: :ok

  def subscribe([topic | topics]) do
    subscribe(topic)
    subscribe(topics)
  end

  def subscribe(topic) when is_binary(topic), do: Phoenix.PubSub.subscribe(@pubsub, topic)

  def broadcast(topic, command) do
    Phoenix.PubSub.broadcast(@pubsub, topic, command)
  end
end
