defmodule PremiereEcoute.Apis.Video.YoutubeApi.Videos do
  @moduledoc """
  YouTube videos API.

  Fetches full video details including statistics and content metadata.
  """

  alias PremiereEcoute.Apis.Video.YoutubeApi

  @doc """
  Fetches full details for a video by ID.

  Requests snippet, statistics, and contentDetails parts.
  Returns a map with title, description, published_at, thumbnail_url, duration, tags,
  view_count, like_count, and comment_count.
  """
  @spec get_video(String.t()) :: {:ok, map()} | {:error, term()}
  def get_video(video_id) when is_binary(video_id) do
    YoutubeApi.api()
    |> YoutubeApi.get(
      url: "/videos",
      params: [
        id: video_id,
        part: "snippet,statistics,contentDetails"
      ]
    )
    |> YoutubeApi.handle(200, fn %{"items" => [item | _]} ->
      snippet = item["snippet"]
      stats = item["statistics"]
      details = item["contentDetails"]

      %{
        id: item["id"],
        url: "https://www.youtube.com/watch?v=#{item["id"]}",
        title: snippet["title"],
        description: snippet["description"],
        published_at: snippet["publishedAt"],
        thumbnail_url:
          get_in(snippet, ["thumbnails", "maxres", "url"]) ||
            get_in(snippet, ["thumbnails", "high", "url"]),
        tags: snippet["tags"] || [],
        duration: details["duration"],
        view_count: String.to_integer(stats["viewCount"] || "0"),
        like_count: String.to_integer(stats["likeCount"] || "0"),
        comment_count: String.to_integer(stats["commentCount"] || "0")
      }
    end)
  end
end
