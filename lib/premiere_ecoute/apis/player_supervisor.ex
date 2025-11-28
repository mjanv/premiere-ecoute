defmodule PremiereEcoute.Apis.PlayerSupervisor do
  @moduledoc """
  Dynamic supervisor for music player processes.

  Manages Spotify player processes dynamically with a maximum of 10 concurrent players, handling player startup, shutdown, and deduplication.
  """

  use DynamicSupervisor

  @doc "Starts the player supervisor."
  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one, max_children: 10)
  end

  @doc """
  Starts a Spotify player process.

  Starts a new player child process or returns existing process if already started. Handles deduplication automatically.
  """
  @spec start(term()) :: {:ok, pid()} | {:error, term()}
  def start(args) do
    case DynamicSupervisor.start_child(__MODULE__, {PremiereEcoute.Apis.SpotifyPlayer, args}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stops a Spotify player process.

  Terminates the player child process identified by PID.
  """
  @spec stop(pid()) :: :ok | {:error, :not_found}
  def stop(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
