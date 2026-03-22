defmodule PremiereEcoute.Apis.Video.YoutubeApi do
  @moduledoc """
  YouTube Data API v3 client.

  Provides access to YouTube Data API v3 for fetching channel and video data.
  Authentication uses an API key passed as a query parameter. No OAuth required for public data.
  """

  use PremiereEcouteCore.Api, api: :youtube

  defmodule Behaviour do
    @moduledoc "YouTube API Behaviour"

    @callback get_channel_videos(channel_id :: String.t()) ::
                {:ok, [map()]} | {:error, term()}
    @callback get_channel(channel_id :: String.t()) ::
                {:ok, map()} | {:error, term()}
    @callback get_video(video_id :: String.t()) ::
                {:ok, map()} | {:error, term()}
    @callback get_comment_threads(video_id :: String.t()) ::
                {:ok, [map()]} | {:error, term()}
    @callback search_track_videos(query :: String.t()) ::
                {:ok, [map()]} | {:error, term()}
    @callback search_artist(name :: String.t()) ::
                {:ok, [map()]} | {:error, term()}
  end

  @doc """
  Creates a Req client for YouTube Data API v3.

  Configures base URL and API key authentication as a query parameter.
  """
  @spec api :: Req.Request.t()
  def api do
    api_key = Application.get_env(:premiere_ecoute, :youtube_data_api_key)

    [
      base_url: url(:api),
      params: [key: api_key],
      headers: [{"Content-Type", "application/json"}]
    ]
    |> new()
  end

  @doc """
  Returns empty client credentials.

  YouTube Data API v3 uses an API key instead of OAuth for public data,
  so this returns empty credentials for compatibility with the API base module.
  """
  @spec client_credentials() :: {:ok, map()}
  def client_credentials, do: {:ok, %{"access_token" => "", "expires_in" => 0}}

  # Channels
  defdelegate get_channel_videos(channel_id), to: __MODULE__.Channels
  defdelegate get_channel(channel_id), to: __MODULE__.ChannelDetails

  # Videos
  defdelegate get_video(video_id), to: __MODULE__.Videos

  # Comments
  defdelegate get_comment_threads(video_id), to: __MODULE__.CommentThreads

  # Search
  defdelegate search_track_videos(query), to: __MODULE__.Search
  defdelegate search_artist(name), to: __MODULE__.Search
end
