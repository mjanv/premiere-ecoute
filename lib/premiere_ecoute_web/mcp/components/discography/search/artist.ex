defmodule PremiereEcouteWeb.Mcp.Components.Discography.Search.Artist do
  @moduledoc "Search for artists by name"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias PremiereEcoute.Discography.Artist

  schema do
    field :name, :string, required: true
  end

  @impl true
  def execute(%{name: name}, frame) do
    artists =
      name
      |> Artist.search()
      |> Enum.map(fn artist -> Map.take(artist, [:id, :name, :slug]) end)

    {:reply, Response.json(Response.tool(), %{artists: artists}), frame}
  end
end
