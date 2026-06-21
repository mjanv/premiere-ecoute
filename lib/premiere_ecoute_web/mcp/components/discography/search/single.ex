defmodule PremiereEcouteWeb.Mcp.Components.Discography.Search.Single do
  @moduledoc "Search for singles (tracks) by name or artist name"

  use Hermes.Server.Component, type: :tool

  alias Hermes.Server.Response
  alias PremiereEcoute.Discography.Single

  schema do
    field :name, :string, required: true
  end

  @impl true
  def execute(%{name: name}, frame) do
    singles =
      name
      |> Single.search()
      |> Enum.map(fn single ->
        %{
          id: single.id,
          name: single.name,
          slug: single.slug,
          cover_url: single.cover_url,
          artist: single.artist
        }
      end)

    {:reply, Response.json(Response.tool(), %{singles: singles}), frame}
  end
end
