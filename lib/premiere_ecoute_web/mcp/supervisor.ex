defmodule PremiereEcouteWeb.Mcp.Supervisor do
  @moduledoc """
  Premiere Ecoute Web service
  """

  use PremiereEcouteCore.Supervisor,
    children: [
      Hermes.Server.Registry,
      {PremiereEcouteWeb.Mcp.Server, transport: :streamable_http}
    ]
end
