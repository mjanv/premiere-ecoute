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

  @doc """
  Injects EventStore subscriber functionality into using module.

  Creates GenServer that subscribes to EventStore stream on init and processes events via handle/1 callback. Stream UUID required in options.
  """
  defmacro __using__(opts) do
    stream_uuid = Keyword.fetch!(opts, :stream)

    quote bind_quoted: [stream_uuid: stream_uuid] do
      use GenServer

      alias EventStore.RecordedEvent
      alias PremiereEcoute.Events.Store

      @doc "Starts subscriber GenServer"
      @spec start_link(term()) :: GenServer.on_start()
      def start_link(args) do
        GenServer.start_link(__MODULE__, args)
      end

      @doc false
      @spec init(term()) :: {:ok, map()}
      def init(_args) do
        :ok = Store.subscribe(unquote(stream_uuid))

        {:ok, %{}}
      end

      @doc false
      @spec handle_info({:events, list(EventStore.RecordedEvent.t())}, map()) :: {:noreply, map()}
      def handle_info({:events, events}, state) do
        Enum.each(events, &handle/1)
        {:noreply, state}
      end
    end
  end
end
