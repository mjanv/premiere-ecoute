defmodule PremiereEcoute.Apis.Video.YoutubeApi.Channels do
  @moduledoc """
  YouTube channels API.

  Lists the videos uploaded to a YouTube channel through its uploads playlist.
  """

  alias PremiereEcoute.Apis.Video.YoutubeApi
  alias PremiereEcoute.Youtube.Video

  @page_size 50
  @max_pages 3
  @channel_id_regex ~r/^UC[\w-]{22}$/

  @doc """
  Fetches the videos uploaded to a YouTube channel, newest first.

  Reads the channel uploads playlist (the channel id with `UC` replaced by `UU`), which lists every
  video of the channel, unlike the search endpoint, and costs 1 quota unit per page instead of 100.
  Follows up to #{@max_pages} pages of #{@page_size} videos. Each `Video` carries its `channel_id`,
  `description` and `privacy` (`:public`, `:unlisted` or `:private`).

  Options:
    * `:since` - a `DateTime`. Videos published before it are dropped and paging stops at the first one.
  """
  @spec get_channel_videos(String.t(), keyword()) :: {:ok, [Video.t()]} | {:error, term()}
  def get_channel_videos(channel_id, opts \\ []) when is_binary(channel_id) do
    if Regex.match?(@channel_id_regex, channel_id) do
      fetch_pages(uploads_playlist_id(channel_id), Keyword.get(opts, :since), nil, 1, [])
    else
      {:error, :invalid_channel_id}
    end
  end

  defp uploads_playlist_id("UC" <> rest), do: "UU" <> rest

  defp fetch_pages(playlist_id, since, page_token, page, acc) do
    case fetch_page(playlist_id, page_token) do
      {:ok, {videos, next_token}} ->
        {recent, older} = Enum.split_while(videos, &published_since?(&1, since))
        acc = acc ++ recent

        if next_token && older == [] && page < @max_pages do
          fetch_pages(playlist_id, since, next_token, page + 1, acc)
        else
          {:ok, acc}
        end

      {:error, _} = error ->
        error
    end
  end

  defp fetch_page(playlist_id, page_token) do
    params =
      [playlistId: playlist_id, part: "snippet,contentDetails,status", maxResults: @page_size]
      |> Keyword.merge(if page_token, do: [pageToken: page_token], else: [])

    YoutubeApi.api()
    |> YoutubeApi.get(url: "/playlistItems", params: params)
    |> YoutubeApi.handle(200, fn %{"items" => items} = body -> {Enum.map(items, &Video.parse/1), body["nextPageToken"]} end)
  end

  defp published_since?(_video, nil), do: true

  defp published_since?(%Video{published_at: published_at}, %DateTime{} = since) do
    case DateTime.from_iso8601(published_at || "") do
      {:ok, published_at, _} -> DateTime.compare(published_at, since) != :lt
      _ -> true
    end
  end
end
