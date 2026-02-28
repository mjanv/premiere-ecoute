defmodule PremiereEcouteCore.Cache.PersistenceHook do
  @moduledoc """
  Cachex hook that persists cache contents to disk across restarts.

  On startup it restores a previous dump once the cache is fully registered,
  then schedules periodic saves. On shutdown it performs a final save before
  going down. The dump path is derived from the cache name and stored under
  `priv/cache/<name>.dump`.

  Pass the cache atom as the hook args:

      hook(module: PremiereEcouteCore.Cache.PersistenceHook, args: :my_cache)
  """

  use Cachex.Hook

  require Logger

  @default_interval :timer.minutes(10)

  @impl true
  def init({cache_name, interval}) do
    Process.flag(:trap_exit, true)
    File.mkdir_p!(dump_path(cache_name) |> Path.dirname())
    interval = if interval == true, do: @default_interval, else: interval
    schedule_save(interval)
    {:ok, {cache_name, interval}}
  end

  # provisions/0 opts into the :cache provision, which is delivered by Cachex.Services.Overseer.update/2 *after* the cache is fully registered. This is the only safe point to call Cachex.restore/2 without a :no_cache race.
  @impl true
  def provisions, do: [:cache]

  @impl true
  def handle_provision({:cache, cache}, {cache_name, _} = state) do
    path = dump_path(cache_name)

    if File.exists?(path) do
      case Cachex.restore(cache, path) do
        {:ok, count} ->
          Logger.info("Cache :#{cache_name} restored #{count} entries from #{path}")

        {:error, reason} ->
          Logger.warning("Cache :#{cache_name} failed to restore from #{path}: #{inspect(reason)}")
      end
    else
      Logger.debug("Cache :#{cache_name} no dump found at #{path}, starting empty")
    end

    {:ok, state}
  end

  @impl true
  def terminate(_reason, {cache_name, _}) do
    Logger.info("Cache :#{cache_name} shutting down, flushing to disk")
    save(cache_name)
  end

  @impl true
  def handle_notify(_action, _result, state), do: {:ok, state}

  @impl true
  def handle_info(:save, {cache_name, save_interval} = state) do
    save(cache_name)
    schedule_save(save_interval)
    {:noreply, state}
  end

  @doc "Saves the named cache to its dump file immediately."
  @spec save(atom()) :: :ok
  def save(cache_name) do
    path = dump_path(cache_name)

    case Cachex.save(cache_name, path) do
      {:ok, true} ->
        Logger.debug("Cache :#{cache_name} saved to #{path}")

      {:error, reason} ->
        Logger.error("Cache :#{cache_name} failed to save to #{path}: #{inspect(reason)}")
    end

    :ok
  end

  defp dump_path(cache_name) do
    Application.app_dir(:premiere_ecoute, "priv/cache/#{cache_name}.dump")
  end

  defp schedule_save(interval) do
    Process.send_after(self(), :save, interval)
  end
end
