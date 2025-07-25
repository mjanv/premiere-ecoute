defmodule PremiereEcoute.Core.Cache do
  @moduledoc false

  require Logger

  def child_spec(opts) do
    %{
      id: opts[:name],
      start: {Cachex, :start_link, [opts[:name]]}
    }
  end

  def clear(cache), do: Cachex.clear(cache)

  def put(cache, key, value, opts \\ []) do
    case Cachex.put(cache, key, value, opts) do
      {:ok, value} ->
        {:ok, value}

      {:error, reason} ->
        Logger.error("Cannot write into cache :#{to_string(cache)}")
        {:error, reason}
    end
  end

  def get(cache, key), do: Cachex.get(cache, key)
end
