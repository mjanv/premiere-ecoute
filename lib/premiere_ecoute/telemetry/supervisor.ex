defmodule PremiereEcoute.Telemetry.Supervisor do
  @moduledoc """
  Telemetry subservice.
  """

  use PremiereEcouteCore.Supervisor, children: [PremiereEcoute.Telemetry.PromEx]
end
