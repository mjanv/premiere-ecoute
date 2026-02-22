defmodule PremiereEcoute.Apis.Streaming.Supervisor do
  @moduledoc """
  Apis Players subservice.
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      PremiereEcoute.Apis.Streaming.TwitchQueue
    ]
end
