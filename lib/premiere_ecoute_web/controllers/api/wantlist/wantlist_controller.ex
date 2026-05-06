defmodule PremiereEcouteWeb.Api.Wantlist.WantlistController do
  @moduledoc """
  API controller for reading the authenticated user's wantlist.
  """

  use PremiereEcouteWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias PremiereEcoute.Wantlists

  @provider_ids_schema %Schema{
    type: :object,
    description: "Provider IDs keyed by provider name (spotify, deezer, tidal)",
    additionalProperties: %Schema{type: :string}
  }

  @item_schema %Schema{
    type: :object,
    properties: %{
      type: %Schema{type: :string, enum: ["album", "track", "artist"]},
      name: %Schema{type: :string},
      artist: %Schema{type: :string, nullable: true},
      provider_ids: @provider_ids_schema
    }
  }

  @wantlist_schema %Schema{
    type: :object,
    properties: %{
      items: %Schema{type: :array, items: @item_schema}
    }
  }

  operation(:show,
    summary: "Get wantlist",
    description: "Returns the authenticated user's wantlist with all items.\n\n**Roles:** streamer, viewer",
    tags: ["Wantlist"],
    security: [%{"bearer" => []}],
    parameters: [
      type: [
        in: :query,
        description: "Filter by item type",
        schema: %Schema{type: :string, enum: ["album", "track", "artist"]},
        required: false
      ]
    ],
    responses: [
      ok: {"Wantlist", "application/json", @wantlist_schema},
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
