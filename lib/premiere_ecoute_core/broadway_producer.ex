defmodule PremiereEcouteCore.BroadwayProducer do
  @moduledoc """
  Broadway producer for event processing.

  Implements a GenStage producer for Broadway pipelines using an in-memory queue with demand-driven event dispatch and load balancing across producer instances.

  ## Usage

  To publish events to a Broadway pipeline:

      PremiereEcouteCore.BroadwayProducer.publish(MyPipeline, %MyEvent{})

  Configure as a producer in your Broadway pipeline:

      defmodule MyPipeline do
        use Broadway

        def start_link(_opts) do
          Broadway.start_link(__MODULE__,
            name: __MODULE__,
            producer: [
              module: {PremiereEcouteCore.BroadwayProducer, []},
              concurrency: 1
            ],
            processors: [
              default: [concurrency: 10]
            ]
          )
        end

        def handle_message(_processor, message, _context) do
          # Process the event
          message
        end
      end
  """

  use GenStage

  alias Broadway.Message
  alias Broadway.NoopAcknowledger

  @doc """
  Publishes an event to a Broadway pipeline.

  Randomly selects a producer from the pipeline and casts the event as a Broadway message. Uses NoopAcknowledger for message acknowledgment.
  """
  @spec publish(atom(), struct()) :: :ok
  def publish(pipeline, event) do
    producer = Enum.random(Broadway.producer_names(pipeline))
    GenStage.cast(producer, %Message{acknowledger: NoopAcknowledger.init(), data: event})
  end

  @doc "Initializes the GenStage producer with an empty queue and zero demand."
  @spec init(term()) :: {:producer, {:queue.queue(), non_neg_integer()}}
  def init(_args), do: {:producer, {:queue.new(), 0}}

  @doc "Handles incoming event casts by adding them to the queue."
  @spec handle_cast(Message.t(), {:queue.queue(), non_neg_integer()}) ::
          {:noreply, list(Message.t()), {:queue.queue(), non_neg_integer()}}
  def handle_cast(%Message{} = event, {queue, demand}), do: dispatch(:queue.in(event, queue), demand, [])

  @doc "Handles demand from consumers by dispatching events from the queue."
  @spec handle_demand(non_neg_integer(), {:queue.queue(), non_neg_integer()}) ::
          {:noreply, list(Message.t()), {:queue.queue(), non_neg_integer()}}
  def handle_demand(consumer_demand, {queue, demand}), do: dispatch(queue, demand + consumer_demand, [])

  defp dispatch(queue, demand, events) when demand > 0 do
    case :queue.out(queue) do
      {{:value, event}, queue} -> dispatch(queue, demand - 1, [event | events])
      {:empty, queue} -> {:noreply, Enum.reverse(events), {queue, demand}}
    end
  end

  defp dispatch(queue, 0, events), do: {:noreply, Enum.reverse(events), {queue, 0}}
end
