defmodule PremiereEcoute.Collections.Supervisor do
  @moduledoc """
  Collection sessions service.
  """

  use PremiereEcouteCore.Supervisor,
    mandatory: [
      {PremiereEcouteCore.Cache, name: :collections, persist: :timer.minutes(30)}
    ],
    optionals: [
      {PremiereEcoute.Collections.CollectionSession.MessagePipeline, []}
    ]
end
