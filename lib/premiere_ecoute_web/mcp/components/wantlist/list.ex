defmodule PremiereEcouteWeb.Mcp.Components.Wantlist.List do
  @moduledoc "The authenticated user's wantlist grouped by type"

  use Hermes.Server.Component,
    type: :resource,
    uri: "user://me/wantlist",
    mime_type: "application/json"

  alias Hermes.Server.Response
  alias PremiereEcoute.Wantlists

  @impl true
  def read(_params, %{assigns: %{current_user: user}} = frame) do
    payload =
      case Wantlists.get_wantlist(user.id) do
        nil ->
          %{albums: [], tracks: [], artists: []}

        wantlist ->
          %{
            albums: Enum.filter(wantlist.items, &(&1.type == :album)) |> Enum.map(&format_album/1),
            tracks: Enum.filter(wantlist.items, &(&1.type == :track)) |> Enum.map(&format_track/1),
            artists: Enum.filter(wantlist.items, &(&1.type == :artist)) |> Enum.map(&format_artist/1)
          }
      end

    {:reply, Response.json(Response.resource(), payload), frame}
  end

  defp format_album(%{id: id, album: album}) do
    %{item_id: id, name: album.name, slug: album.slug, release_date: album.release_date, cover_url: album.cover_url}
  end

  defp format_track(%{id: id, single: single}) do
    %{item_id: id, name: single.name, slug: single.slug, cover_url: single.cover_url}
  end

  defp format_artist(%{id: id, artist: artist}) do
    %{item_id: id, name: artist.name, slug: artist.slug}
  end
end
