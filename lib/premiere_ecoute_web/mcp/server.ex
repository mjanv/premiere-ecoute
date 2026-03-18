defmodule PremiereEcouteWeb.Mcp.Server do
  @moduledoc false

  alias PremiereEcouteWeb.Mcp.Components

  use Hermes.Server,
    name: "premiere-ecoute",
    version: "1.0.0",
    capabilities: [:tools]

  component(Components.Greeter)
  component(Components.AlbumSearch)
end
