defmodule PremiereEcouteWeb.Mcp.Components.AlbumSearch do
  @moduledoc "Search for albums in our catalog"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias PremiereEcoute.Discography.Album

  schema do
    field :name, :string, required: true
  end

  @impl true
  def execute(%{name: name}, frame) do
    albums =
      Album.all(where: [name: name])
      |> Enum.map(fn album -> Map.take(album, [:name, :release_date, :total_tracks]) end)

    {:reply, Response.json(Response.tool(), albums), frame}
  end
end
