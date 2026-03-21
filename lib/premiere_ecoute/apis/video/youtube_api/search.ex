defmodule PremiereEcoute.Apis.Video.YoutubeApi.Search do
  @moduledoc """
  YouTube search API.

  Searches for videos matching a query, filtered to the Music category.
  """

  alias PremiereEcoute.Apis.Video.YoutubeApi

  @doc """
  Searches YouTube for videos matching a track query.

  Filters to Music category (ID 10), ordered by relevance.
  Returns up to 10 results with id, title, channel_title, published_at, and thumbnail_url.
  """
  @spec search_track_videos(String.t()) :: {:ok, [map()]} | {:error, term()}
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
      Enum.map(items, fn %{"id" => %{"videoId" => video_id}, "snippet" => snippet} ->
        %{
          id: video_id,
          url: "https://www.youtube.com/watch?v=#{video_id}",
          title: snippet["title"],
          channel_title: snippet["channelTitle"],
          published_at: snippet["publishedAt"],
          thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"])
        }
      end)
    end)
  end
end
