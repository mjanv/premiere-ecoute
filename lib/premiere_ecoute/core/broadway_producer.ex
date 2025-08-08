defmodule PremiereEcoute.Core.BroadwayProducer do
  @moduledoc false

  use GenStage

  alias Broadway.Message
  alias Broadway.NoopAcknowledger

  def publish(pipeline, event) do
    producer = Enum.random(Broadway.producer_names(pipeline))
    GenStage.cast(producer, %Message{acknowledger: NoopAcknowledger.init(), data: event})
  end

  def init(_args), do: {:producer, {:queue.new(), 0}}
  def handle_cast(%Message{} = event, {queue, demand}), do: dispatch(:queue.in(event, queue), demand, [])
  def handle_demand(consumer_demand, {queue, demand}), do: dispatch(queue, demand + consumer_demand, [])

  defp dispatch(queue, demand, events) when demand > 0 do
    case :queue.out(queue) do
      {{:value, event}, queue} -> dispatch(queue, demand - 1, [event | events])
      {:empty, queue} -> {:noreply, Enum.reverse(events), {queue, demand}}
    end
  end

  defp dispatch(queue, 0, events), do: {:noreply, Enum.reverse(events), {queue, 0}}
end
