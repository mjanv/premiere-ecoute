defmodule PremiereEcouteWeb.Mcp.Components.Wantlist.Add do
  @moduledoc "Adds an item to the authenticated user's wantlist"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias PremiereEcoute.Wantlists

  schema do
    field :type, :string, required: true
    field :record_id, :integer, required: true
  end

  @impl true
  def execute(%{type: type, record_id: record_id}, %{assigns: %{current_user: user}} = frame) do
    with {:ok, type} <- parse_type(type),
         {:ok, _item} <- Wantlists.add_item(user.id, type, record_id) do
      {:reply, Response.text(Response.tool(), "Added to wantlist."), frame}
    else
      {:error, :invalid_type} ->
        {:reply, Response.error(Response.tool(), "Invalid type. Must be album, track, or artist."), frame}

      {:error, _changeset} ->
        {:reply, Response.error(Response.tool(), "Failed to add item. It may already be in the wantlist."), frame}
    end
  end

  defp parse_type("album"), do: {:ok, :album}
  defp parse_type("track"), do: {:ok, :track}
  defp parse_type("artist"), do: {:ok, :artist}
  defp parse_type(_), do: {:error, :invalid_type}
end
