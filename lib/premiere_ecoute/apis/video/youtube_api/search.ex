defmodule PremiereEcoute.Apis.Video.YoutubeApi.Search do
  @moduledoc """
  YouTube search API.

  Searches for videos matching a query, filtered to the Music category.
  """

  alias PremiereEcoute.Apis.Video.YoutubeApi
  alias PremiereEcoute.Youtube.Channel
  alias PremiereEcoute.Youtube.Video

  @doc """
  Searches YouTube for a music artist channel by name.

  Uses the search endpoint with type=channel, filtered to Music category (ID 10).
  Returns only exact name matches (case-insensitive) as `Channel` structs (id and title).
  The channel id can be used to build a YouTube Music URL: https://music.youtube.com/channel/{id}
  """
  @spec search_artist(String.t()) :: {:ok, [Channel.t()]} | {:error, term()}
  def search_artist(name) when is_binary(name) do
    name_downcase = String.downcase(name)

    YoutubeApi.api()
    |> YoutubeApi.get(
      url: "/search",
      params: [
        q: name,
        part: "snippet",
        type: "channel",
        maxResults: 10
      ]
    )
    |> YoutubeApi.handle(200, fn %{"items" => items} ->
      items
      |> Enum.filter(fn %{"snippet" => snippet} ->
        String.downcase(snippet["channelTitle"]) == name_downcase
      end)
      |> Enum.map(&Channel.parse/1)
    end)
  end

  @doc """
  Searches YouTube for videos matching a track query.

  Filters to Music category (ID 10), ordered by relevance.
  Returns up to 10 `Video` structs (summary fields only).
  """
  @spec search_track_videos(String.t()) :: {:ok, [Video.t()]} | {:error, term()}
  def search_track_videos(query) when is_binary(query) do
    YoutubeApi.api()
    |> YoutubeApi.get(
      url: "/search",
      params: [
        q: query,
        part: "snippet",
        type: "video",
        videoCategoryId: "10",
        order: "relevance",
        maxResults: 10
      ]
    )
    |> YoutubeApi.handle(200, fn %{"items" => items} ->
      Enum.map(items, &Video.parse/1)
    end)
  end
end
