defmodule PremiereEcoute.Apis.Video.YoutubeApi.Channels do
  @moduledoc """
  YouTube channels API.

  Fetches the latest videos uploaded to a YouTube channel.
  """

  alias PremiereEcoute.Apis.Video.YoutubeApi

  @doc """
  Fetches the latest videos for a YouTube channel.

  Uses the search endpoint to list the most recent uploads (up to 50) for the given channel ID.
  Returns a list of maps with video metadata: id, title, description, published_at, thumbnail_url.
  """
  @spec get_channel_videos(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_channel_videos(channel_id) when is_binary(channel_id) do
    YoutubeApi.api()
    |> YoutubeApi.get(
      url: "/search",
      params: [
        channelId: channel_id,
        part: "snippet",
        order: "date",
        type: "video",
        maxResults: 50
      ]
    )
    |> YoutubeApi.handle(200, fn %{"items" => items} ->
      Enum.map(items, fn %{"id" => %{"videoId" => video_id}, "snippet" => snippet} ->
        %{
          id: video_id,
          url: "https://www.youtube.com/watch?v=#{video_id}",
          title: snippet["title"],
          description: snippet["description"],
          published_at: snippet["publishedAt"],
          thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"])
        }
      end)
    end)
  end
end
