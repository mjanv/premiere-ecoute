defmodule PremiereEcoute.Apis.MusicProvider.DeezerApi.Tracks do
  @moduledoc """
  Deezer tracks API.

  Fetches individual track data from Deezer API and parses into Track structs.
  """

  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Discography.Album.Track

  @doc """
  Fetches a Deezer track by ID.

  Retrieves track metadata from Deezer API. Parses response into a Track struct.
  """
  @spec get_track(String.t()) :: {:ok, Track.t()} | {:error, term()}
  def get_track(track_id) when is_binary(track_id) do
    DeezerApi.api()
    |> DeezerApi.get(url: "/track/#{track_id}")
    |> DeezerApi.handle(200, &parse_track/1)
  end

  @spec parse_track(map()) :: Track.t()
  defp parse_track(data) do
    %Track{
      provider: :deezer,
      track_id: data["id"],
      album_id: data["album"]["id"],
      name: data["title"],
      track_number: data["track_position"] || 0,
      duration_ms: 1_000 * String.to_integer(data["duration"] || "0")
    }
  end
end
