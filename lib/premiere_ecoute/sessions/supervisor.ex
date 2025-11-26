defmodule PremiereEcoute.Sessions.Supervisor do
  @moduledoc """
  Listening sessions service.

  Manages the sessions cache and, outside of test, the Broadway pipelines for processing chat messages and poll results.
  """

  use Supervisor

  alias PremiereEcouteCore.Cache

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    mandatory = [
      {Cache, name: :sessions}
    ]

    optionals =
      case Application.get_env(:premiere_ecoute, :environment) do
        :test ->
          []

        _ ->
          [
            {PremiereEcoute.Sessions.Scores.MessagePipeline, []},
            {PremiereEcoute.Sessions.Scores.PollPipeline, []}
          ]
      end

    Supervisor.init(mandatory ++ optionals, strategy: :one_for_one)
  end
end
