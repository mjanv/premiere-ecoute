defmodule PremiereEcouteWeb.Mcp.Components.Discography.Search.Album do
  @moduledoc "Search for albums by album/artist name, or list all albums for a given artist_id"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias PremiereEcoute.Discography.Album

  schema do
    field :name, :string
    field :artist_id, :integer
  end

  @impl true
  def execute(%{artist_id: artist_id}, frame) when not is_nil(artist_id) do
    albums =
      artist_id
      |> Album.list_for_artist()
      |> Enum.map(&format/1)

    {:reply, Response.json(Response.tool(), %{albums: albums}), frame}
  end

  def execute(%{name: name}, frame) when not is_nil(name) do
    albums =
      Album.search(name)
      |> Enum.map(&format/1)

    {:reply, Response.json(Response.tool(), %{albums: albums}), frame}
  end

  def execute(_params, frame) do
    {:reply, Response.error(Response.tool(), "Provide either `name` or `artist_id`."), frame}
  end

  defp format(album), do: Map.take(album, [:id, :name, :release_date, :total_tracks, :artist])
end
