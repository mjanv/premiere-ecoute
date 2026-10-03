defmodule PremiereEcoute.Youtube.Video do
  @moduledoc """
  Represents a YouTube video.

  Built from a `videos` resource (full details), a `search` result or a `playlistItems` entry (summary only).
  Fields missing from the source resource are `nil` (`tags` defaults to `[]`).
  """

  @type id :: String.t()

  @type t :: %__MODULE__{
          id: id(),
          url: String.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          channel_id: String.t() | nil,
          channel_title: String.t() | nil,
          published_at: String.t() | nil,
          privacy: :public | :unlisted | :private | nil,
          thumbnail_url: String.t() | nil,
          tags: [String.t()],
          duration: String.t() | nil,
          view_count: non_neg_integer() | nil,
          like_count: non_neg_integer() | nil,
          comment_count: non_neg_integer() | nil
        }

  defstruct [
    :id,
    :url,
    :title,
    :description,
    :channel_id,
    :channel_title,
    :published_at,
    :privacy,
    :thumbnail_url,
    :duration,
    :view_count,
    :like_count,
    :comment_count,
    tags: []
  ]

  @spec parse(map()) :: t()
  def parse(%{"kind" => "youtube#playlistItem", "contentDetails" => %{"videoId" => id} = details, "snippet" => snippet} = data) do
    snippet =
      snippet
      |> Map.put("publishedAt", details["videoPublishedAt"] || snippet["publishedAt"])
      |> Map.put("channelId", snippet["videoOwnerChannelId"] || snippet["channelId"])
      |> Map.put("channelTitle", snippet["videoOwnerChannelTitle"] || snippet["channelTitle"])

    build(id, Map.put(data, "snippet", snippet))
  end

  def parse(%{"id" => %{"videoId" => id}} = data), do: build(id, data)
  def parse(%{"id" => id} = data), do: build(id, data)

  defp build(id, data) do
    snippet = data["snippet"] || %{}
    stats = data["statistics"]

    %__MODULE__{
      id: id,
      url: "https://www.youtube.com/watch?v=#{id}",
      title: snippet["title"],
      description: snippet["description"],
      channel_id: snippet["channelId"],
      channel_title: snippet["channelTitle"],
      published_at: snippet["publishedAt"],
      privacy: privacy(get_in(data, ["status", "privacyStatus"])),
      thumbnail_url: get_in(snippet, ["thumbnails", "maxres", "url"]) || get_in(snippet, ["thumbnails", "high", "url"]),
      tags: snippet["tags"] || [],
      duration: get_in(data, ["contentDetails", "duration"]),
      view_count: count(stats, "viewCount"),
      like_count: count(stats, "likeCount"),
      comment_count: count(stats, "commentCount")
    }
  end

  defp privacy("public"), do: :public
  defp privacy("unlisted"), do: :unlisted
  defp privacy("private"), do: :private
  defp privacy(_), do: nil

  defp count(nil, _key), do: nil
  defp count(stats, key), do: String.to_integer(stats[key] || "0")
end
