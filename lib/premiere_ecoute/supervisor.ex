defmodule PremiereEcoute.Supervisor do
  @moduledoc """
  Premiere Ecoute backend service

  Starts subservices for telemetry, database, event store, accounts, external APIs, billboards, and sessions.
  """

  use Supervisor

  @doc """
  Starts backend supervisor with all subservices.

  Initializes supervisor process for telemetry, database, event store, accounts, external APIs, billboards, and session management services.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
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
      PremiereEcoute.Sessions.Supervisor,
      PremiereEcoute.Radio.EventHandler
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
