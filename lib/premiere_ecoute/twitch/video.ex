defmodule PremiereEcoute.Twitch.Video do
  @moduledoc """
  Represents a Twitch video (past broadcast, highlight or upload).
  """

  @type id :: String.t()
  @type type :: :archive | :highlight | :upload

  @type t :: %__MODULE__{
          id: id(),
          stream_id: String.t() | nil,
          user_id: String.t(),
          user_login: String.t(),
          user_name: String.t(),
          title: String.t(),
          description: String.t(),
          created_at: String.t(),
          published_at: String.t(),
          url: String.t(),
          thumbnail_url: String.t(),
          viewable: String.t(),
          view_count: non_neg_integer(),
          language: String.t(),
          type: type() | nil,
          duration: String.t(),
          muted_segments: [%{duration: non_neg_integer(), offset: non_neg_integer()}]
        }

  defstruct [
    :id,
    :stream_id,
    :user_id,
    :user_login,
    :user_name,
    :title,
    :description,
    :created_at,
    :published_at,
    :url,
    :thumbnail_url,
    :viewable,
    :view_count,
    :language,
    :type,
    :duration,
    muted_segments: []
  ]

  @types %{"archive" => :archive, "highlight" => :highlight, "upload" => :upload}

  @doc """
  Parses a Twitch API video.
  """
  @spec parse(map()) :: t()
  def parse(data) do
    %__MODULE__{
      id: data["id"],
      stream_id: data["stream_id"],
      user_id: data["user_id"],
      user_login: data["user_login"],
      user_name: data["user_name"],
      title: data["title"],
      description: data["description"],
      created_at: data["created_at"],
      published_at: data["published_at"],
      url: data["url"],
      thumbnail_url: data["thumbnail_url"],
      viewable: data["viewable"],
      view_count: data["view_count"],
      language: data["language"],
      type: Map.get(@types, data["type"]),
      duration: data["duration"],
      muted_segments: for(s <- data["muted_segments"] || [], do: %{duration: s["duration"], offset: s["offset"]})
    }
  end
end
