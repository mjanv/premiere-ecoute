defmodule PremiereEcoute.Core.Subscriber do
  @moduledoc false

  defmacro __using__(opts) do
    stream_uuid = Keyword.fetch!(opts, :stream)

    quote bind_quoted: [stream_uuid: stream_uuid] do
      use GenServer

      alias EventStore.RecordedEvent
      alias PremiereEcoute.EventStore

      def start_link(args) do
        GenServer.start_link(__MODULE__, args)
      end

      def init(_args) do
        :ok = EventStore.subscribe(unquote(stream_uuid))

        {:ok, %{}}
      end

      def handle_info({:events, events}, state) do
        Enum.each(events, &handle/1)
        {:noreply, state}
      end
    end
  end
end
