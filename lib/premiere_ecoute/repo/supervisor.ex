defmodule PremiereEcoute.Repo.Supervisor do
  @moduledoc """
  Repositories subservice.

  Manages the Ecto repo, Ecto encryption vault, and Oban job processor.
  """

  use Supervisor

  @doc """
  Starts repository supervisor with database and job processing.

  Initializes supervisor process for Ecto repo, encryption vault, and Oban background job processor.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      PremiereEcoute.Repo,
      PremiereEcoute.Repo.Vault,
      {Oban, Application.fetch_env!(:premiere_ecoute, Oban)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
