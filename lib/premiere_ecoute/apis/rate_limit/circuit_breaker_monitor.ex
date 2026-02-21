defmodule PremiereEcoute.Apis.RateLimit.CircuitBreakerMonitor do
  @moduledoc """
  Cachex hook for the :rate_limits cache.

  Listens to put/del/purge events and broadcasts the current set of
  rate-limited APIs via PubSub so subscribers update immediately without
  polling.
  """

  use Cachex.Hook

  alias PremiereEcoute.PubSub

  @topic "rate_limits"

  @spec topic() :: String.t()
  def topic, do: @topic

  @impl true
  def actions, do: [:put, :del, :purge, :clear]

  @impl true
  def init(_opts), do: {:ok, nil}

  @impl true
  def handle_notify(_action, {:ok, _}, _state) do
    PubSub.broadcast(@topic, {:rate_limits, apis()})
    {:ok, nil}
  end

  def handle_notify(_action, _result, state), do: {:ok, state}

  defp apis do
    :rate_limits
    |> Cachex.stream!()
    |> Enum.flat_map(fn {:entry, key, value, modified, expiration} ->
      if value do
        [{key, value, expiration && DateTime.from_unix!(modified + expiration, :millisecond)}]
      else
        []
      end
    end)
    |> Enum.sort_by(fn {key, _, _} -> key end)
  rescue
    _ -> []
  end
end
