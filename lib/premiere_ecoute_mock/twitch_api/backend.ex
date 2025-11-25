defmodule PremiereEcouteMock.TwitchApi.Backend do
  @moduledoc """
  Mock Twitch API state backend.

  GenServer maintaining in-memory state for mock Twitch API data like subscriptions and polls during development and testing.
  """

  use GenServer

  require Logger

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def init(state), do: {:ok, state}

  def get(key, default \\ nil), do: GenServer.call(__MODULE__, {:get, key}) || default
  def put(key, value), do: GenServer.cast(__MODULE__, {:put, key, value})
  def update(key, default, f), do: key |> get(default) |> f.() |> tap(fn v -> put(key, v) end)

  def handle_call({:get, key}, _from, state), do: {:reply, Map.get(state, key), state}
  def handle_cast({:put, key, value}, state), do: {:noreply, Map.put(state, key, value)}
end
