defmodule PremiereEcoute.Events.Store do
  @moduledoc """
  Event store implementation

  Provides event persistence and retrieval capabilities with conditional event appending based on operation results. This module wraps the EventStore library to offer simplified interfaces for reading event streams and appending events with optional metadata.
  """

  use EventStore, otp_app: :premiere_ecoute, enable_hard_deletes: false

  @doc """
  Reads events from a stream.

  Returns event data (`:event` mode) or raw RecordedEvent structs (`:raw` mode). Returns empty list if stream doesn't exist.
  """
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

  @doc """
  Retrieves the last N events from a stream.

  Returns a single event for n=1, a list of events for n>1, or nil if stream doesn't exist. Events are returned in chronological order.
  """
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

  @doc """
  Paginates through events in a stream.

  Returns a page of RecordedEvent structs as maps. Defaults to page 1 with 10 events per page.
  """
  @spec paginate(String.t(), Keyword.t()) :: [EventStore.RecordedEvent.t()]
  def paginate(stream_uuid, opts \\ [page: 1, size: 10]) do
    case __MODULE__.read_stream_forward(stream_uuid, (opts[:page] - 1) * opts[:size] + 1, opts[:size]) do
      {:ok, events} -> Enum.map(events, fn %EventStore.RecordedEvent{} = event -> Map.from_struct(event) end)
      {:error, _} -> []
    end
  end

  @doc """
  Appends an event to the event store.

  Wraps the event in EventData with UUID and metadata. If stream option is provided, appends to both singular and plural stream names.
  """
  @spec append(map(), Keyword.t()) :: :ok
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

  @doc """
  Conditionally appends an event on successful operations.

  Appends the result of calling function f on success data, then returns the original success tuple. Passes through other patterns unchanged.
  """
  @spec ok({:ok, any()} | any(), String.t() | nil, (any() -> any())) :: {:ok, any()} | any()
  def ok(pattern, stream \\ nil, f)

  def ok({:ok, data}, stream, f) do
    append(f.(data), stream: stream)
    {:ok, data}
  end

  def ok(pattern, _stream, _f), do: pattern

  @doc """
  Conditionally appends an event on error operations.

  Appends the result of calling function g on error data, then returns the original error tuple. Passes through other patterns unchanged.
  """
  @spec error({:error, any()} | any(), String.t() | nil, (any() -> any())) :: {:error, any()} | any()
  def error(pattern, stream \\ nil, g)

  def error({:error, data}, stream, g) do
    append(g.(data), stream: stream)
    {:error, data}
  end

  def error(pattern, _stream, _g), do: pattern

  @doc """
  Unconditionally appends an event for any operation result.

  Appends the result of calling function h on the data regardless of success or failure, then returns the original data unchanged.
  """
  @spec any({:ok, any()} | {:error, any()} | any(), String.t() | nil, (any() -> any())) ::
          {:ok, any()} | {:error, any()} | any()
  def any(data, stream, h) do
    append(h.(data), stream: stream)
    data
  end
end
