defmodule PremiereEcoute.Apis.Video.YoutubeApi.CommentThreads do
  @moduledoc """
  YouTube comment threads API.

  Fetches top-level comments for a video.
  """

  alias PremiereEcoute.Apis.Video.YoutubeApi

  @doc """
  Fetches the latest comments for a video.

  Returns up to 20 top-level comment threads ordered by time.
  Each entry contains id, author, text, like_count, published_at, and total_reply_count.
  """
  @spec get_comment_threads(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_comment_threads(video_id) when is_binary(video_id) do
    YoutubeApi.api()
    |> YoutubeApi.get(
      url: "/commentThreads",
      params: [
        videoId: video_id,
        part: "snippet",
        order: "time",
        maxResults: 20
      ]
    )
    |> YoutubeApi.handle(200, fn %{"items" => items} ->
      Enum.map(items, fn item ->
        comment = get_in(item, ["snippet", "topLevelComment", "snippet"])

        %{
          id: item["id"],
          author: comment["authorDisplayName"],
          text: comment["textOriginal"],
          like_count: comment["likeCount"],
          published_at: comment["publishedAt"],
          total_reply_count: item["snippet"]["totalReplyCount"]
        }
      end)
    end)
  end
end
