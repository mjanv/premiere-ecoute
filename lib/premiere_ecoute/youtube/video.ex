defmodule PremiereEcoute.Youtube.Video do
  @moduledoc """
  Represents a YouTube video.

  Built from either a `videos` resource (full details) or a `search` result (summary only).
  Fields missing from the source resource are `nil` (`tags` defaults to `[]`).
  """

  @type id :: String.t()

  @type t :: %__MODULE__{
          id: id(),
          url: String.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          channel_title: String.t() | nil,
          published_at: String.t() | nil,
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
    :channel_title,
    :published_at,
    :thumbnail_url,
    :duration,
    :view_count,
    :like_count,
    :comment_count,
    tags: []
  ]

  @spec parse(map()) :: t()
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
      channel_title: snippet["channelTitle"],
      published_at: snippet["publishedAt"],
      thumbnail_url: get_in(snippet, ["thumbnails", "maxres", "url"]) || get_in(snippet, ["thumbnails", "high", "url"]),
      tags: snippet["tags"] || [],
      duration: get_in(data, ["contentDetails", "duration"]),
      view_count: count(stats, "viewCount"),
      like_count: count(stats, "likeCount"),
      comment_count: count(stats, "commentCount")
    }
  end

  defp count(nil, _key), do: nil
  defp count(stats, key), do: String.to_integer(stats[key] || "0")
end
