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

  @doc """
  Finds the 30 s preview of a track.

  Returns the preview URL of the first match, falling back to the first track found for the artist alone, or `nil` when nothing has a preview. Preview URLs are signed and expire: do not store them.
  """
  @spec get_track_preview(String.t(), String.t()) :: {:ok, String.t() | nil} | {:error, term()}
  def get_track_preview(artist, title) when is_binary(artist) and is_binary(title) do
    with {:ok, nil} <- search_preview("#{artist} #{title}") do
      search_preview(artist)
    end
  end

  defp search_preview(q) do
    DeezerApi.api()
    |> DeezerApi.get(url: "/search", params: [q: q, limit: 5])
    |> DeezerApi.handle(200, fn
      %{"data" => items} ->
        Enum.find_value(items, fn
          %{"preview" => "http" <> _ = preview} -> preview
          _ -> nil
        end)

      # Deezer reports errors such as an exceeded quota in a 200 response without data
      _ ->
        nil
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
      provider_ids: %{deezer: to_string(data["id"])},
      name: data["title"],
      track_number: 0,
      duration_ms: data["duration"] * 1_000
    }
  end
end
