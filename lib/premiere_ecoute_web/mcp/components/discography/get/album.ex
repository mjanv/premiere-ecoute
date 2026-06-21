defmodule PremiereEcouteWeb.Mcp.Components.Discography.Get.Album do
  @moduledoc "Fetch a full album with its tracks and artists by album id"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias PremiereEcoute.Discography.Album

  schema do
    field :album_id, :integer, required: true
  end

  @impl true
  def execute(%{album_id: album_id}, frame) do
    case Album.get(album_id) do
      nil ->
        {:reply, Response.error(Response.tool(), "Album not found."), frame}

      album ->
        {:reply, Response.json(Response.tool(), format(album)), frame}
    end
  end

  defp format(album) do
    %{
      id: album.id,
      name: album.name,
      slug: album.slug,
      release_date: album.release_date,
      cover_url: album.cover_url,
      total_tracks: album.total_tracks,
      external_links: album.external_links,
      artists: Enum.map(album.artists, &%{id: &1.id, name: &1.name, slug: &1.slug}),
      tracks:
        album.tracks
        |> Enum.sort_by(& &1.track_number)
        |> Enum.map(
          &%{
            id: &1.id,
            name: &1.name,
            track_number: &1.track_number,
            duration_ms: &1.duration_ms
          }
        )
    }
  end
end
