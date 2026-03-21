defmodule PremiereEcoute.Apis.Video.YoutubeApi.ChannelDetails do
  @moduledoc """
  YouTube channel details API.

  Fetches channel metadata, statistics, and related playlist IDs.
  """

  alias PremiereEcoute.Apis.Video.YoutubeApi

  @doc """
  Fetches details for a channel by ID.

  Requests snippet, statistics, and contentDetails parts.
  Returns a map with title, description, custom_url, published_at, thumbnail_url,
  country, subscriber_count, video_count, view_count, and uploads_playlist_id.
  """
  @spec get_channel(String.t()) :: {:ok, map()} | {:error, term()}
  def get_channel(channel_id) when is_binary(channel_id) do
    YoutubeApi.api()
    |> YoutubeApi.get(
      url: "/channels",
      params: [
        id: channel_id,
        part: "snippet,statistics,contentDetails"
      ]
    )
    |> YoutubeApi.handle(200, fn %{"items" => [item | _]} ->
      snippet = item["snippet"]
      stats = item["statistics"]
      uploads = get_in(item, ["contentDetails", "relatedPlaylists", "uploads"])

      %{
        id: item["id"],
        title: snippet["title"],
        description: snippet["description"],
        custom_url: snippet["customUrl"],
        published_at: snippet["publishedAt"],
        thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"]),
        country: snippet["country"],
        subscriber_count: String.to_integer(stats["subscriberCount"] || "0"),
        video_count: String.to_integer(stats["videoCount"] || "0"),
        view_count: String.to_integer(stats["viewCount"] || "0"),
        uploads_playlist_id: uploads
      }
    end)
  end
end
