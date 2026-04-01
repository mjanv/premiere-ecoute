defmodule PremiereEcoute.Explorer.Services.ResolveQuery do
  @moduledoc """
  Resolves a freeform query string to a concrete entity for the Explorer.

  Resolution order:
  1. Case-insensitive artist name match in internal DB → `{:artist, %Artist{}}`
  2. Case-insensitive album name match in internal DB  → `{:album, %Album{}}`
  3. Wikipedia search fallback                         → `{:wikipedia, %Page{}}`
  """

  import Ecto.Query

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Repo

  @doc """
  Resolves a freeform query to the most relevant entity.

  Returns `{:ok, {:artist | :album | :wikipedia, entity}}` or `{:error, :not_found}`.
  """
  @spec resolve(String.t()) ::
          {:ok, {:artist, Artist.t()} | {:album, Album.t()} | {:wikipedia, map()}}
          | {:error, :not_found | term()}
  def resolve(query) when is_binary(query) do
    query = String.trim(query)

    with :not_found <- find_artist(query),
         :not_found <- find_album(query) do
      search_wikipedia(query)
    else
      {:ok, entity} -> {:ok, entity}
    end
  end

  defp find_artist(name) do
    name_lower = String.downcase(name)

    from(a in Artist, where: fragment("LOWER(?)", a.name) == ^name_lower)
    |> Repo.one()
    |> case do
      nil -> :not_found
      artist -> {:ok, {:artist, artist}}
    end
  end

  defp find_album(name) do
    name_lower = String.downcase(name)

    case from(a in Album, where: fragment("LOWER(?)", a.name) == ^name_lower) |> Repo.one() do
      nil -> :not_found
      album -> {:ok, {:album, Album.preload(album)}}
    end
  end

  defp search_wikipedia(query) do
    case Apis.wikipedia().search(artist: query) do
      {:ok, [page | _]} -> {:ok, {:wikipedia, page}}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end
end
