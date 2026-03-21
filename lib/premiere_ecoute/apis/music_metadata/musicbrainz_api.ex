defmodule PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi do
  @moduledoc """
  MusicBrainz API client.

  Provides access to the MusicBrainz Web Service v2 for music metadata lookups.
  No authentication required for read-only requests. Rate limit: 1 request/second.
  """

  use PremiereEcouteCore.Api, api: :musicbrainz

  @user_agent "PremièreEcoute/1.0 (maxime.janvier@gmail.com)"

  defmodule Behaviour do
    @moduledoc "MusicBrainz API Behaviour"

    @callback search_recordings(query :: String.t()) :: {:ok, [map()]} | {:error, term()}
    @callback get_recording(mbid :: String.t()) :: {:ok, map()} | {:error, term()}
    @callback search_release_groups(query :: String.t()) :: {:ok, [map()]} | {:error, term()}
    @callback get_release_group(mbid :: String.t()) :: {:ok, map()} | {:error, term()}
    @callback search_artists(query :: String.t()) :: {:ok, [map()]} | {:error, term()}
    @callback get_artist(mbid :: String.t()) :: {:ok, map()} | {:error, term()}
  end

  @doc """
  Creates a Req client for MusicBrainz API.

  Sets the mandatory User-Agent header and requests JSON responses via fmt=json.
  """
  @spec api :: Req.Request.t()
  def api do
    [
      base_url: url(:api),
      params: [fmt: "json"],
      headers: [
        {"User-Agent", @user_agent},
        {"Accept", "application/json"}
      ]
    ]
    |> new()
  end

  @doc """
  Returns empty client credentials.

  MusicBrainz does not require authentication for read-only requests.
  """
  @spec client_credentials() :: {:ok, map()}
  def client_credentials, do: {:ok, %{"access_token" => "", "expires_in" => 0}}

  # Recordings
  defdelegate search_recordings(query), to: __MODULE__.Recordings
  defdelegate get_recording(mbid), to: __MODULE__.Recordings

  # Release groups
  defdelegate search_release_groups(query), to: __MODULE__.ReleaseGroups
  defdelegate get_release_group(mbid), to: __MODULE__.ReleaseGroups

  # Artists
  defdelegate search_artists(query), to: __MODULE__.Artists
  defdelegate get_artist(mbid), to: __MODULE__.Artists
end
