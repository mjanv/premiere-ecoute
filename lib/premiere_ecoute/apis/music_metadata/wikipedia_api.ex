defmodule PremiereEcoute.Apis.MusicMetadata.WikipediaApi do
  @moduledoc """
  Wikipedia API client.

  Provides access to the Wikipedia Web API for searching artist and album pages.
  No authentication required. Rate limit: polite crawling expected via User-Agent.
  """

  use PremiereEcouteCore.Api, api: :wikipedia

  @user_agent "PremièreEcoute/1.0 (maxime.janvier@gmail.com)"

  defmodule Behaviour do
    @moduledoc "Wikipedia API Behaviour"

    @callback search_artist(name :: String.t()) :: {:ok, [map()]} | {:error, term()}
    @callback search_album(title :: String.t(), artist :: String.t()) ::
                {:ok, [map()]} | {:error, term()}
  end

  @doc """
  Creates a Req client for Wikipedia API.

  Sets the mandatory User-Agent header and requests JSON responses.
  """
  @spec api :: Req.Request.t()
  def api do
    [
      base_url: url(:api),
      headers: [
        {"User-Agent", @user_agent},
        {"Accept", "application/json"}
      ]
    ]
    |> new()
  end

  @doc """
  Returns empty client credentials.

  Wikipedia does not require authentication for read-only requests.
  """
  @spec client_credentials() :: {:ok, map()}
  def client_credentials, do: {:ok, %{"access_token" => "", "expires_in" => 0}}

  # Search
  defdelegate search_artist(name), to: __MODULE__.Search
  defdelegate search_album(title, artist), to: __MODULE__.Search
end
