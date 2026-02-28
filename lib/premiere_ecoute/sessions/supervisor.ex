defmodule PremiereEcoute.Sessions.Supervisor do
  @moduledoc """
  Listening sessions service.
  """

  use PremiereEcouteCore.Supervisor,
    mandatory: [
      {PremiereEcouteCore.Cache, name: :sessions, persist: :timer.minutes(5)}
    ],
    optionals: [
      {PremiereEcoute.Sessions.Scores.MessagePipeline, []},
      {PremiereEcoute.Sessions.Scores.PollPipeline, []}
    ]
end
