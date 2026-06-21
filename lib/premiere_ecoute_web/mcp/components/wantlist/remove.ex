defmodule PremiereEcouteWeb.Mcp.Components.Wantlist.Remove do
  @moduledoc "Removes an item from the authenticated user's wantlist by item ID"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias PremiereEcoute.Wantlists

  schema do
    field :item_id, :integer, required: true
  end

  @impl true
  def execute(%{item_id: item_id}, %{assigns: %{current_user: user}} = frame) do
    case Wantlists.remove_item(user.id, item_id) do
      {:ok, _item} ->
        {:reply, Response.text(Response.tool(), "Removed from wantlist."), frame}

      {:error, :not_found} ->
        {:reply, Response.error(Response.tool(), "Item not found in wantlist."), frame}
    end
  end
end
