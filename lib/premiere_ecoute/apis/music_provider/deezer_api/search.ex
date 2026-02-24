defmodule PremiereEcoute.Apis.MusicProvider.DeezerApi.Search do
  @moduledoc """
  Deezer search API.

  Searches the Deezer catalog for tracks using a keyword list with optional field filters (query, artist, track, album).
  """

  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Discography.Album.Track

  @doc """
  Searches Deezer catalog for tracks.

  Accepts a keyword list with one of: query, artist, track, album.
  Builds the appropriate Deezer advanced search query and returns a list of Track structs.
  """
  @spec search_tracks(Keyword.t()) :: {:ok, [Track.t()]} | {:error, term()}
  def search_tracks(query) when is_list(query) do
    q = build_query(query)

    DeezerApi.api()
    |> DeezerApi.get(url: "/search", params: [q: q])
    |> DeezerApi.handle(200, fn %{"data" => items} ->
      Enum.map(items, &parse_track/1)
    end)
  end

  @spec build_query(Keyword.t()) :: String.t()
  defp build_query(query) do
    cond do
      q = query[:query] -> q
      q = query[:artist] -> ~s(artist:"#{q}")
      q = query[:track] -> ~s(track:"#{q}")
      q = query[:album] -> ~s(album:"#{q}")
    end
  end

  @spec parse_track(map()) :: Track.t()
  defp parse_track(data) do
    %Track{
      provider: :deezer,
      track_id: to_string(data["id"]),
      name: data["title"],
      track_number: 0,
      duration_ms: data["duration"] * 1_000
    }
  end
end
