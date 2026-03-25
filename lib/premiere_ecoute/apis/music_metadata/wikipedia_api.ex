defmodule PremiereEcoute.Apis.MusicMetadata.WikipediaApi do
  @moduledoc """
  Wikipedia API client.

  Provides access to the Wikipedia Web API for searching artist and album pages.
  No authentication required. Rate limit: polite crawling expected via User-Agent.
  """

  use PremiereEcouteCore.Api, api: :wikipedia

  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.PageSummary
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Search
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Page
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi.Types.Summary

  defmodule Behaviour do
    @moduledoc "Wikipedia API Behaviour"

    @callback search(query :: Search.query()) :: {:ok, [Page.t()]} | {:error, term()}
    @callback summary(page :: Page.t()) :: {:ok, Summary.t()} | {:error, term()}
  end

  @doc """
  Creates a Req client for the Wikipedia MediaWiki action API.

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
  Creates a Req client for the Wikipedia REST API v1.

  Used for endpoints under /api/rest_v1 such as page summaries.
  """
  @spec rest_api :: Req.Request.t()
  def rest_api do
    [
      base_url: url(:rest),
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
  defdelegate search(query), to: Search

  # PageSummary
  defdelegate summary(page), to: PageSummary
end
