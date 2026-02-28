defmodule PremiereEcouteCore.Cache do
  @moduledoc """
  Cache utilities.

  Provides a wrapper around Cachex for managing application caches with operations for clearing, deleting, getting, and putting values.
  """

  import Cachex.Spec

  require Logger

  alias PremiereEcouteCore.Cache.PersistenceHook

  @doc """
  Generates child specification for cache supervision.

  Creates Cachex child spec with cache name from opts for starting under supervisor.
  Accepts `persist: true | milliseconds` to enable disk persistence across restarts
  via `PremiereEcouteCore.Cache.PersistenceHook`. `true` uses the default interval
  defined in the hook; an integer overrides it.
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    {name, cachex_opts} = Keyword.pop!(opts, :name)
    {persist, cachex_opts} = Keyword.pop(cachex_opts, :persist, false)

    cachex_opts =
      case persist do
        false ->
          cachex_opts

        interval ->
          hook = hook(module: PersistenceHook, args: {name, interval})
          Keyword.update(cachex_opts, :hooks, [hook], &[hook | &1])
      end

    %{
      id: name,
      start: {Cachex, :start_link, [name, cachex_opts]}
    }
  end

  @doc "Clears all entries from cache"
  @spec clear(atom()) :: {:ok, true} | {:error, term()}
  def clear(cache), do: Cachex.clear(cache)

  @doc "Deletes key from cache"
  @spec del(atom(), term()) :: {:ok, boolean()} | {:error, term()}
  def del(cache, key), do: Cachex.del(cache, key)

  @doc """
  Puts value in cache with optional TTL.

  Stores key-value pair in cache with optional expiration. Logs errors on failure.
  """
  @spec put(atom(), term(), term(), keyword()) :: {:ok, term()} | {:error, term()}
  def put(cache, key, value, opts \\ []) do
    case Cachex.put(cache, key, value, opts) do
      {:ok, value} ->
        {:ok, value}

      {:error, reason} ->
        Logger.error("Cannot write into cache :#{to_string(cache)}")
        {:error, reason}
    end
  end

  @doc "Retrieves value from cache by key"
  @spec get(atom(), term()) :: {:ok, term()} | {:error, term()}
  def get(cache, key), do: Cachex.get(cache, key)

  @doc "Retrieves value from cache by key"
  @spec ttl(atom(), term()) :: {:ok, term()} | {:error, term()}
  def ttl(cache, key), do: Cachex.ttl(cache, key)
end
