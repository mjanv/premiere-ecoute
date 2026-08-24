defmodule PremiereEcoute.Telemetry.Supervisor do
  @moduledoc """
  Telemetry subservice.
  """

  alias PremiereEcoute.Telemetry.PromEx
  alias PremiereEcoute.Telemetry.Tracing

  use PremiereEcouteCore.Supervisor,
    children: [PromEx],
    optionals: [{Task, &Tracing.setup/0}]
end
