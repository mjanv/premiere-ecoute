defmodule PremiereEcoute.Apis.Video.YoutubeApi.Videos do
  @moduledoc """
  YouTube videos API.

  Fetches full video details including statistics and content metadata.
  """

  alias PremiereEcoute.Apis.Video.YoutubeApi
  alias PremiereEcoute.Youtube.Video

  @doc """
  Fetches full details for a video by ID.

  Requests snippet, statistics, contentDetails, and status parts.
  Returns a `Video` with title, description, channel_id, published_at, privacy, thumbnail_url, duration, tags,
  view_count, like_count, and comment_count.
  """
  @spec get_video(String.t()) :: {:ok, Video.t()} | {:error, term()}
  def get_video(video_id) when is_binary(video_id) do
    YoutubeApi.api()
    |> YoutubeApi.get(
      url: "/videos",
      params: [
        id: video_id,
        part: "snippet,statistics,contentDetails,status"
      ]
    )
    |> YoutubeApi.handle(200, fn %{"items" => [item | _]} -> Video.parse(item) end)
  end
end
