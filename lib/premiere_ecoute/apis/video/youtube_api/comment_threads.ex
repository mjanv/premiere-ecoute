defmodule PremiereEcoute.Apis.Video.YoutubeApi.CommentThreads do
  @moduledoc """
  YouTube comment threads API.

  Fetches top-level comments for a video.
  """

  alias PremiereEcoute.Apis.Video.YoutubeApi
  alias PremiereEcoute.Youtube.Comment

  @doc """
  Fetches the latest comments for a video.

  Returns up to 20 top-level comment threads ordered by time.
  Each entry is a `Comment`.
  """
  @spec get_comment_threads(String.t()) :: {:ok, [Comment.t()]} | {:error, term()}
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
    |> YoutubeApi.handle(200, fn %{"items" => items} -> Enum.map(items, &Comment.parse/1) end)
  end
end
