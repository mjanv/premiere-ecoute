defmodule PremiereEcoute.Youtube.Comment do
  @moduledoc """
  Represents a top-level YouTube comment thread.
  """

  @type id :: String.t()

  @type t :: %__MODULE__{
          id: id(),
          author: String.t(),
          text: String.t(),
          like_count: non_neg_integer(),
          published_at: String.t(),
          total_reply_count: non_neg_integer()
        }

  defstruct [:id, :author, :text, :like_count, :published_at, :total_reply_count]

  @spec parse(map()) :: t()
  def parse(data) do
    comment = get_in(data, ["snippet", "topLevelComment", "snippet"])

    %__MODULE__{
      id: data["id"],
      author: comment["authorDisplayName"],
      text: comment["textOriginal"],
      like_count: comment["likeCount"],
      published_at: comment["publishedAt"],
      total_reply_count: data["snippet"]["totalReplyCount"]
    }
  end
end
