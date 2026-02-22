defmodule PremiereEcoute.Supervisor do
  @moduledoc """
  Premiere Ecoute backend service

  Starts subservices for telemetry, database, event store, accounts, external APIs, billboards, and sessions.
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      PremiereEcoute.Telemetry.Supervisor,
      PremiereEcoute.Repo.Supervisor,
      PremiereEcoute.Events.Supervisor,
      PremiereEcoute.Accounts.Supervisor,
      PremiereEcoute.Apis.Supervisor,
      PremiereEcoute.Billboards.Supervisor,
      PremiereEcoute.Sessions.Supervisor,
      PremiereEcoute.Radio.EventHandler
    ]
end
