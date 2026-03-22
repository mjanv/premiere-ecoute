defmodule PremiereEcoute.Apis.MusicProvider.TidalApi do
  @moduledoc """
  Tidal API client.

  Provides access to Tidal Open API (v2) for fetching artist and album data.
  Authentication uses OAuth2 client credentials flow.
  """

  use PremiereEcouteCore.Api,
    api: :tidal,
    behaviours: [
      PremiereEcoute.Apis.MusicProvider.Albums
    ]

  defmodule Behaviour do
    @moduledoc "Tidal API Behaviour"

    @callback placeholder() :: any()
    @optional_callbacks placeholder: 0
  end

  @doc """
  Creates a Req client for Tidal API with Bearer token authentication.
  """
  @spec api() :: Req.Request.t()
  def api do
    access_token = token(nil)

    [
      base_url: url(:api),
      headers: [
        {"Content-Type", "application/vnd.api+json"},
        {"Authorization", "Bearer #{access_token}"}
      ]
    ]
    |> new()
  end

  @doc """
  Fetches client credentials token from Tidal OAuth2 endpoint.
  """
  @spec client_credentials() :: {:ok, map()} | {:error, term()}
  def client_credentials do
    client_id = Application.get_env(:premiere_ecoute, :tidal_client_id)
    client_secret = Application.get_env(:premiere_ecoute, :tidal_client_secret)

    [base_url: url(:accounts)]
    |> new()
    |> post(
      url: "/oauth2/token",
      form: [
        grant_type: "client_credentials",
        client_id: client_id,
        client_secret: client_secret
      ]
    )
    |> handle(200, & &1)
  end

  # Albums
  defdelegate get_album(album_id), to: __MODULE__.Albums
  defdelegate get_track(track_id), to: __MODULE__.Tracks

  # Artists
  defdelegate search_artist(artist_id), to: __MODULE__.Artists
  defdelegate get_artist(artist_id), to: __MODULE__.Artists
  defdelegate get_artist_albums(artist_id), to: __MODULE__.Artists
end
