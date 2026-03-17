defmodule PremiereEcouteWeb.Mcp.Components.Greeter do
  @moduledoc "Greet someone warmly"

  use Hermes.Server.Component, type: :tool
  alias Hermes.Server.Response

  schema do
    field :name, :string, required: true
  end

  def execute(%{name: name}, frame) do
    response =
      Response.tool()
      |> Response.text("Hello #{name}! Welcome to the MCP world!")

    {:reply, response, frame}
  end
end
