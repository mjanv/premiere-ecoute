defmodule PremiereEcoute.Repo.Release do
  @moduledoc """
  Release tools

  Used for executing DB release tasks when run in production without Mix installed.
  """

  alias EventStore.Tasks
  alias PremiereEcoute.Events.Store

  @app :premiere_ecoute

  @doc """
  Runs database migrations in production.

  Creates and initializes EventStore then runs all Ecto migrations. Used for release deployments without Mix.
  """
  @spec migrate :: :ok
  def migrate do
    load_app()

    config = Store.config()
    :ok = Tasks.Create.exec(config, [])
    :ok = Tasks.Init.exec(config, [])

    for repo <- Application.fetch_env!(@app, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Rolls back database to specific version.

  Reverts Ecto migrations down to specified version for given repository.
  """
  @spec rollback(module(), integer()) :: {:ok, term(), term()}
  def rollback(repo, version) do
    load_app()

    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
