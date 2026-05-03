defmodule PremiereEcouteWeb.Api.Wantlist.WantlistController do
  @moduledoc """
  API controller for reading the authenticated user's wantlist.
  """

  use PremiereEcouteWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias PremiereEcoute.Wantlists

  @item_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer},
      type: %Schema{type: :string, enum: ["album", "track", "artist"]},
      album_id: %Schema{type: :integer, nullable: true},
      single_id: %Schema{type: :integer, nullable: true},
      artist_id: %Schema{type: :integer, nullable: true},
      inserted_at: %Schema{type: :string, format: :"date-time"}
    }
  }

  @wantlist_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer},
      items: %Schema{type: :array, items: @item_schema}
    }
  }

  operation(:show,
    summary: "Get wantlist",
    description: "Returns the authenticated user's wantlist with all items.\n\n**Roles:** streamer, viewer",
    tags: ["Wantlist"],
    security: [%{"bearer" => []}],
    responses: [
      ok: {"Wantlist", "application/json", @wantlist_schema},
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(%{assigns: %{current_scope: %{user: user}}} = conn, _params) do
    wantlist = Wantlists.impl().get_wantlist(user.id)

    conn
    |> put_status(:ok)
    |> json(serialize_wantlist(wantlist))
  end

  defp serialize_wantlist(nil), do: %{id: nil, items: []}

  defp serialize_wantlist(wantlist) do
    %{
      id: wantlist.id,
      items: Enum.map(wantlist.items, &serialize_item/1)
    }
  end

  defp serialize_item(item) do
    %{
      id: item.id,
      type: item.type,
      album_id: item.album_id,
      single_id: item.single_id,
      artist_id: item.artist_id,
      inserted_at: item.inserted_at
    }
  end
end
