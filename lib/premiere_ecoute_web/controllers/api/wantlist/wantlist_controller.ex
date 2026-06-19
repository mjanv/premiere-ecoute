defmodule PremiereEcouteWeb.Api.Wantlist.WantlistController do
  @moduledoc """
  API controller for reading the authenticated user's wantlist.
  """

  use PremiereEcouteWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias PremiereEcoute.Wantlists
  alias PremiereEcouteWeb.Schemas

  operation(:show,
    summary: "Get wantlist",
    description: "Returns the authenticated user's wantlist with all items.",
    tags: ["Wantlist"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer", "viewer"],
    parameters: [
      type: [
        in: :query,
        description: "Filter by item type",
        schema: %Schema{type: :string, enum: ["album", "track", "artist"]},
        required: false
      ]
    ],
    responses: [
      ok: {"Wantlist", "application/json", Schemas.Wantlist},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(%{assigns: %{current_scope: %{user: user}}} = conn, params) do
    wantlist = Wantlists.impl().get_wantlist(user.id)
    type_filter = params["type"]

    conn
    |> put_status(:ok)
    |> json(serialize_wantlist(wantlist, type_filter))
  end

  defp serialize_wantlist(nil, _type_filter), do: %{items: []}

  defp serialize_wantlist(wantlist, type_filter) do
    items =
      wantlist.items
      |> filter_by_type(type_filter)
      |> Enum.map(&serialize_item/1)

    %{items: items}
  end

  defp filter_by_type(items, nil), do: items
  defp filter_by_type(items, type), do: Enum.filter(items, &(to_string(&1.type) == type))

  defp serialize_item(%{type: :album, album: album}) do
    %{
      type: :album,
      name: album.name,
      artist: artist_name(album.artist),
      provider_ids: album.provider_ids
    }
  end

  defp serialize_item(%{type: :track, single: single}) do
    %{
      type: :track,
      name: single.name,
      artist: artist_name(single.artist),
      provider_ids: single.provider_ids
    }
  end

  defp serialize_item(%{type: :artist, artist: artist}) do
    %{
      type: :artist,
      name: artist.name,
      artist: nil,
      provider_ids: artist.provider_ids
    }
  end

  defp artist_name(nil), do: nil
  defp artist_name(artist), do: to_string(artist)
end
