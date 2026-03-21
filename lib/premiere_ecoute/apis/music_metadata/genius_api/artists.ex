defmodule PremiereEcoute.Apis.MusicMetadata.GeniusApi.Artists do
  @moduledoc """
  Genius artists API.

  Searches for artists by name and fetches artist details by Genius artist ID.
  """

  alias PremiereEcoute.Apis.MusicMetadata.GeniusApi

  @doc """
  Searches Genius for an artist by name.

  Queries the search endpoint and extracts the primary artist from the first
  matching song hit. Returns `{:ok, map()}` with artist fields, or `{:ok, nil}`
  if no results are found.
  """
  @spec search_artist(String.t()) :: {:ok, map() | nil} | {:error, term()}
  def search_artist(query) when is_binary(query) do
    GeniusApi.api()
    |> GeniusApi.get(url: "/search", params: [q: query])
    |> GeniusApi.handle(200, fn %{"response" => %{"hits" => hits}} ->
      hits
      |> Enum.filter(fn hit -> hit["type"] == "song" end)
      |> case do
        [] -> nil
        [%{"result" => result} | _] -> parse_artist(result["primary_artist"])
      end
    end)
  end

  @doc """
  Fetches details for an artist by Genius artist ID.

  Returns a map with id, name, url, image_url, header_image_url,
  followers_count, and social links.
  """
  @spec get_artist(integer()) :: {:ok, map()} | {:error, term()}
  def get_artist(id) when is_integer(id) do
    GeniusApi.api()
    |> GeniusApi.get(url: "/artists/#{id}")
    |> GeniusApi.handle(200, fn %{"response" => %{"artist" => artist}} ->
      parse_artist(artist)
    end)
  end

  defp parse_artist(artist) do
    %{
      id: artist["id"],
      name: artist["name"],
      url: artist["url"],
      image_url: artist["image_url"],
      header_image_url: artist["header_image_url"],
      is_verified: artist["is_verified"],
      followers_count: artist["followers_count"],
      twitter_name: artist["twitter_name"],
      instagram_name: artist["instagram_name"],
      facebook_name: artist["facebook_name"]
    }
  end
end
