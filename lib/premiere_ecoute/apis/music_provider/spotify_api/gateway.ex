defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.Gateway do
  @moduledoc false

  use GenServer

  @interval 250
  @timeout 10_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{last_call: System.monotonic_time(:millisecond)}, name: __MODULE__)
  end

  def call(module, function, args), do: GenServer.call(__MODULE__, {:call, module, function, args}, @timeout)

  def init(state), do: {:ok, state}

  def handle_call({:call, module, function, args}, _from, state) do
    since_ms = System.monotonic_time(:millisecond) - state.last_call
    if since_ms < @interval, do: Process.sleep(@interval - since_ms)

    {:reply, apply(module, function, args), %{state | last_call: System.monotonic_time(:millisecond)}}
  end
end
