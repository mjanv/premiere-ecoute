defmodule PremiereEcoute.Youtube.Channel do
  @moduledoc """
  Represents a YouTube channel.

  Built from either a `channels` resource (full details) or a `search` result (id and title only).
  Fields missing from the source resource are `nil`.
  """

  @type id :: String.t()

  @type t :: %__MODULE__{
          id: id(),
          title: String.t(),
          description: String.t() | nil,
          custom_url: String.t() | nil,
          published_at: String.t() | nil,
          thumbnail_url: String.t() | nil,
          country: String.t() | nil,
          subscriber_count: non_neg_integer() | nil,
          video_count: non_neg_integer() | nil,
          view_count: non_neg_integer() | nil,
          uploads_playlist_id: String.t() | nil
        }

  defstruct [
    :id,
    :title,
    :description,
    :custom_url,
    :published_at,
    :thumbnail_url,
    :country,
    :subscriber_count,
    :video_count,
    :view_count,
    :uploads_playlist_id
  ]

  @spec parse(map()) :: t()
  def parse(%{"id" => %{"channelId" => id}, "snippet" => snippet}) do
    %__MODULE__{
      id: id,
      title: snippet["channelTitle"],
      description: snippet["description"],
      published_at: snippet["publishedAt"],
      thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"])
    }
  end

  def parse(%{"id" => id} = data) do
    snippet = data["snippet"] || %{}
    stats = data["statistics"] || %{}

    %__MODULE__{
      id: id,
      title: snippet["title"],
      description: snippet["description"],
      custom_url: snippet["customUrl"],
      published_at: snippet["publishedAt"],
      thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"]),
      country: snippet["country"],
      subscriber_count: String.to_integer(stats["subscriberCount"] || "0"),
      video_count: String.to_integer(stats["videoCount"] || "0"),
      view_count: String.to_integer(stats["viewCount"] || "0"),
      uploads_playlist_id: get_in(data, ["contentDetails", "relatedPlaylists", "uploads"])
    }
  end
end
