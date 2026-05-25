defmodule PremiereEcouteWeb.Api.Wantlist.ItemController do
  @moduledoc """
  API controller for removing items from the authenticated user's wantlist.
  """

  use PremiereEcouteWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema
  alias PremiereEcoute.Wantlists

  @ok_schema %Schema{
    type: :object,
    properties: %{ok: %Schema{type: :boolean}}
  }

  operation(:delete,
    summary: "Remove wantlist item",
    description: "Removes an item from the authenticated user's wantlist.",
    tags: ["Wantlist"],
    security: [%{"bearer" => []}],
    "x-role": ["streamer", "viewer"],
    parameters: [
      id: [in: :path, description: "Wantlist item ID", type: :integer, required: true]
    ],
    responses: [
      ok: {"Item removed", "application/json", @ok_schema},
      not_found: "Item not found or not owned by user",
      unauthorized: "Missing or invalid Authorization header"
    ]
  )

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(%{assigns: %{current_scope: %{user: user}}} = conn, %{"id" => id}) do
    with {int_id, ""} <- Integer.parse(id),
         {:ok, _item} <- Wantlists.impl().remove_item(user.id, int_id) do
      conn
      |> put_status(:ok)
      |> json(%{ok: true})
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Item not found"})
    end
  end
end
