defmodule PremiereEcoute.Apis.Video.YoutubeApi.Channels do
  @moduledoc """
  YouTube channels API.

  Fetches the latest videos uploaded to a YouTube channel.
  """

  alias PremiereEcoute.Apis.Video.YoutubeApi
  alias PremiereEcoute.Youtube.Video

  @doc """
  Fetches the latest videos for a YouTube channel.

  Uses the search endpoint to list the most recent uploads (up to 50) for the given channel ID.
  Returns a list of `Video` structs (summary fields only).
  """
  @spec get_channel_videos(String.t()) :: {:ok, [Video.t()]} | {:error, term()}
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
    |> YoutubeApi.handle(200, fn %{"items" => items} -> Enum.map(items, &Video.parse/1) end)
  end
end
