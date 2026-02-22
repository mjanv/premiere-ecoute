defmodule PremiereEcoute.Repo.Supervisor do
  @moduledoc """
  Repositories subservice.
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      PremiereEcoute.Repo,
      PremiereEcoute.Repo.Vault,
      {Oban, Application.fetch_env!(:premiere_ecoute, Oban)}
    ]
end
