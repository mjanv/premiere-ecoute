defmodule PremiereEcoute.Release do
  @moduledoc """
  Release tools

  Used for executing DB release tasks when run in production without Mix installed.
  """

  @app :premiere_ecoute

  def migrate do
    load_app()

    # config = PremiereEcoute.EventStore.config()
    # :ok = EventStore.Tasks.Create.exec(config, [])
    # :ok = EventStore.Tasks.Init.exec(config, [])

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()

    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Application.ensure_all_started(:postgrex)
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
