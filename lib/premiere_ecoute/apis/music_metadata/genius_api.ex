defmodule PremiereEcoute.Apis.MusicMetadata.GeniusApi do
  @moduledoc """
  Genius API client.

  Provides access to the Genius API for searching songs and fetching song details.
  Authentication uses a Bearer access token.
  """

  use PremiereEcouteCore.Api, api: :genius

  defmodule Behaviour do
    @moduledoc "Genius API Behaviour"

    @callback search_song(query :: String.t()) :: {:ok, [map()]} | {:error, term()}
    @callback get_song(id :: integer()) :: {:ok, map()} | {:error, term()}
    @callback search_artist(query :: String.t()) :: {:ok, map() | nil} | {:error, term()}
    @callback get_artist(id :: integer()) :: {:ok, map()} | {:error, term()}
  end

  @doc """
  Creates a Req client for Genius API.

  Configures base URL and Bearer token authentication from application config.
  """
  @spec api :: Req.Request.t()
  def api do
    token = Application.get_env(:premiere_ecoute, :genius_access_token)

    [
      base_url: url(:api),
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"Content-Type", "application/json"}
      ]
    ]
    |> new()
  end

  @doc """
  Returns empty client credentials.

  Genius uses a static Bearer token instead of OAuth client credentials flow.
  """
  @spec client_credentials() :: {:ok, map()}
  def client_credentials, do: {:ok, %{"access_token" => "", "expires_in" => 0}}

  # Search
  defdelegate search_song(query), to: __MODULE__.Search

  # Songs
  defdelegate get_song(id), to: __MODULE__.Songs

  # Artists
  defdelegate search_artist(query), to: __MODULE__.Artists
  defdelegate get_artist(id), to: __MODULE__.Artists
end
