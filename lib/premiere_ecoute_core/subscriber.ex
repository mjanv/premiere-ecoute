defmodule PremiereEcouteCore.Subscriber do
  @moduledoc """
  Base module for EventStore subscribers.

  Provides a GenServer-based subscriber that automatically subscribes to an EventStore stream and processes events through a `handle/1` callback function. Modules using this must implement their own event handling logic.

  ## Options

  - `:stream` - Required. The UUID of the EventStore stream to subscribe to

  ## Usage

      defmodule MySubscriber do
        use PremiereEcouteCore.Subscriber, stream: "my-stream-uuid"

        def handle(%RecordedEvent{event_type: "MyEvent", data: data}) do
          # Process the event
        end
      end
  """

  defmacro __using__(opts) do
    stream_uuid = Keyword.fetch!(opts, :stream)

    quote bind_quoted: [stream_uuid: stream_uuid] do
      use GenServer

      alias EventStore.RecordedEvent
      alias PremiereEcoute.Events.Store

      def start_link(args) do
        GenServer.start_link(__MODULE__, args)
      end

      def init(_args) do
        :ok = Store.subscribe(unquote(stream_uuid))

        {:ok, %{}}
      end

      def handle_info({:events, events}, state) do
        Enum.each(events, &handle/1)
        {:noreply, state}
      end
    end
  end
end
