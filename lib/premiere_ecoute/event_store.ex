defmodule PremiereEcoute.EventStore do
  @moduledoc """
  Event store implementation

  Provides event persistence and retrieval capabilities with conditional event appending based on operation results. This module wraps the EventStore library to offer simplified interfaces for reading event streams and appending events with optional metadata.
  """

  use EventStore, otp_app: :premiere_ecoute, enable_hard_deletes: false

  @spec read(String.t(), :event | :raw) :: [any()]
  def read(stream_uuid, type \\ :event)

  def read(stream_uuid, :event) do
    case __MODULE__.read_stream_forward(stream_uuid) do
      {:ok, events} -> Enum.map(events, fn %EventStore.RecordedEvent{data: event} -> event end)
      {:error, _} -> []
    end
  end

  def read(stream_uuid, :raw) do
    case __MODULE__.read_stream_forward(stream_uuid) do
      {:ok, events} -> events
      {:error, _} -> []
    end
  end

  @spec last(String.t(), integer()) :: any()
  def last(stream_uuid, n \\ 1) do
    case __MODULE__.read_stream_backward(stream_uuid, -1, n) do
      {:ok, [%EventStore.RecordedEvent{data: event}]} ->
        event

      {:ok, [%EventStore.RecordedEvent{} | _] = events} ->
        Enum.map(events, fn %EventStore.RecordedEvent{data: event} -> event end) |> Enum.reverse()

      {:error, _} ->
        nil
    end
  end

  @spec paginate(String.t(), Keyword.t()) :: [EventStore.RecordedEvent.t()]
  def paginate(stream_uuid, opts \\ [page: 1, size: 10]) do
    case __MODULE__.read_stream_forward(stream_uuid, (opts[:page] - 1) * opts[:size] + 1, opts[:size]) do
      {:ok, events} -> Enum.map(events, fn %EventStore.RecordedEvent{} = event -> Map.from_struct(event) end)
      {:error, _} -> []
    end
  end

  def append(event, opts \\ []) do
    event = %EventData{
      data: event,
      event_id: UUID.uuid4(),
      event_type: Atom.to_string(event.__struct__),
      metadata: opts[:metadata] || %{}
    }

    if opts[:stream] do
      __MODULE__.append_to_stream(singular(opts[:stream]) <> to_string(event.data.id), :any_version, [event])
      __MODULE__.link_to_stream(plural(opts[:stream]), :any_version, [event.event_id])
    end

    :ok
  end

  defp singular(stream), do: stream <> "-"
  defp plural(stream), do: stream <> "s"

  def ok(pattern, stream \\ nil, f)

  def ok({:ok, data}, stream, f) do
    append(f.(data), stream: stream)
    {:ok, data}
  end

  def ok(pattern, _stream, _f), do: pattern

  def error(pattern, stream \\ nil, g)

  def error({:error, data}, stream, g) do
    append(g.(data), stream: stream)
    {:error, data}
  end

  def error(pattern, _stream, _g), do: pattern

  def any(data, stream, h) do
    append(h.(data), stream: stream)
    data
  end
end
