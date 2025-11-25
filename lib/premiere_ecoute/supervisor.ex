defmodule PremiereEcoute.Supervisor do
  @moduledoc """
  Premiere Ecoute backend service

  Starts subservices for telemetry, database, event store, accounts, external APIs, billboards, and sessions.
  """

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      PremiereEcoute.Telemetry.Supervisor,
      PremiereEcoute.Repo.Supervisor,
      PremiereEcoute.Events.Supervisor,
      PremiereEcoute.Accounts.Supervisor,
      PremiereEcoute.Apis.Supervisor,
      PremiereEcoute.Billboards.Supervisor,
      PremiereEcoute.Sessions.Supervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
