defmodule PremiereEcouteMock.TwitchApi.Backend do
  @moduledoc """
  Mock Twitch API state backend.

  GenServer maintaining in-memory state for mock Twitch API data like subscriptions and polls during development and testing.
  """

  use GenServer

  require Logger

  @doc """
  Starts the mock backend GenServer.

  Launches a named GenServer with empty initial state for storing mock Twitch API data.
  """
  @spec start_link(term()) :: GenServer.on_start()
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @doc false
  @spec init(map()) :: {:ok, map()}
  def init(state), do: {:ok, state}

  @doc """
  Retrieves value from mock backend state.

  Returns the value for the key, or the default if key doesn't exist.
  """
  @spec get(term(), term()) :: term()
  def get(key, default \\ nil), do: GenServer.call(__MODULE__, {:get, key}) || default

  @doc """
  Stores value in mock backend state.

  Asynchronously updates the state with the key-value pair.
  """
  @spec put(term(), term()) :: :ok
  def put(key, value), do: GenServer.cast(__MODULE__, {:put, key, value})

  @doc """
  Updates value in mock backend state.

  Retrieves current value (or default), applies transformation function, and stores the result.
  """
  @spec update(term(), term(), (term() -> term())) :: term()
  def update(key, default, f), do: key |> get(default) |> f.() |> tap(fn v -> put(key, v) end)

  @spec handle_call({:get, term()}, GenServer.from(), map()) :: {:reply, term(), map()}
  def handle_call({:get, key}, _from, state), do: {:reply, Map.get(state, key), state}

  @spec handle_cast({:put, term(), term()}, map()) :: {:noreply, map()}
  def handle_cast({:put, key, value}, state), do: {:noreply, Map.put(state, key, value)}
end
