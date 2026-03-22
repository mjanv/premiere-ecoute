defmodule PremiereEcoute.Apis.MusicProvider.TidalApi.Tracks do
  @moduledoc """
  Tidal tracks API.

  Fetches individual track data from Tidal Open API v2.
  """

  alias PremiereEcoute.Apis.MusicProvider.TidalApi
  alias PremiereEcoute.Apis.MusicProvider.TidalApi.Parser
  alias PremiereEcoute.Discography.Album.Track

  @doc """
  Fetches a track by Tidal ID.

  Returns a Track struct with provider_ids, name, and duration populated.
  Track number defaults to 0 as it is not available without album context.
  """
  @spec get_track(String.t()) :: {:ok, Track.t()} | {:error, term()}
  def get_track(track_id) when is_binary(track_id) do
    TidalApi.api()
    |> TidalApi.get(url: "/tracks", params: [{"filter[id]", track_id}, {"countryCode", "US"}])
    |> TidalApi.handle(200, fn data ->
      track = hd(data["data"])

      %Track{
        provider_ids: %{tidal: track["id"]},
        name: track["attributes"]["title"],
        track_number: 0,
        duration_ms: Parser.parse_duration_ms(track["attributes"]["duration"])
      }
    end)
  end
end
