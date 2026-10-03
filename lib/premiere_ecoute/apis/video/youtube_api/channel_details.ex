defmodule PremiereEcoute.Apis.Video.YoutubeApi.ChannelDetails do
  @moduledoc """
  YouTube channel details API.

  Fetches channel metadata, statistics, and related playlist IDs.
  """

  alias PremiereEcoute.Apis.Video.YoutubeApi
  alias PremiereEcoute.Youtube.Channel

  @doc """
  Fetches details for a channel by ID.

  Requests snippet, statistics, and contentDetails parts.
  Returns a `Channel` with title, description, custom_url, published_at, thumbnail_url,
  country, subscriber_count, video_count, view_count, and uploads_playlist_id.
  """
  @spec get_channel(String.t()) :: {:ok, Channel.t()} | {:error, term()}
  def get_channel(channel_id) when is_binary(channel_id) do
    YoutubeApi.api()
    |> YoutubeApi.get(
      url: "/channels",
      params: [
        id: channel_id,
        part: "snippet,statistics,contentDetails"
      ]
    )
    |> YoutubeApi.handle(200, fn %{"items" => [item | _]} -> Channel.parse(item) end)
  end
end
