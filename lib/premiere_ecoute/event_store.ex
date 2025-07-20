defmodule PremiereEcoute.EventStore do
  @moduledoc false

  use EventStore, otp_app: :premiere_ecoute

  def read(stream_uuid) do
    case __MODULE__.read_stream_forward(stream_uuid) do
      {:ok, events} -> Enum.map(events, fn %EventStore.RecordedEvent{data: event} -> event end)
      {:error, _} -> []
    end
  end

  def append(event, stream_uuid, metadata \\ %{}) do
    event = %EventData{
      event_type: Atom.to_string(event.__struct__),
      data: event,
      metadata: metadata
    }

    __MODULE__.append_to_stream(stream_uuid, :any_version, [event])
  end

  def ok({:ok, data}, stream_uuid, f) do
    append(f.(data), stream_uuid)
    {:ok, data}
  end

  def ok(pattern, _stream_uuid, _f), do: pattern

  def error({:error, data}, stream_uuid, g) do
    append(g.(data), stream_uuid)
    {:error, data}
  end

  def error(pattern, _stream_uuid, _g), do: pattern

  def ok_or({:ok, data}, stream_uuid, f, _g) do
    append(f.(data), stream_uuid)
    {:ok, data}
  end

  def ok_or({:error, data}, stream_uuid, _f, g) do
    append(g.(data), stream_uuid)
    {:error, data}
  end
end
