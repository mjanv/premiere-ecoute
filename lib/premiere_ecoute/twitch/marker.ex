defmodule PremiereEcoute.Twitch.Marker do
  @moduledoc """
  Represents a Twitch stream marker.
  """

  @type id :: String.t()

  @type t :: %__MODULE__{
          id: id(),
          created_at: String.t(),
          description: String.t() | nil,
          position_seconds: non_neg_integer(),
          url: String.t() | nil,
          video_id: String.t() | nil
        }

  defstruct [:id, :created_at, :description, :position_seconds, :url, :video_id]

  @spec parse(map()) :: t()
  def parse(data) do
    %__MODULE__{
      id: data["id"],
      created_at: data["created_at"],
      description: data["description"],
      position_seconds: data["position_seconds"],
      url: data["URL"],
      video_id: data["video_id"]
    }
  end
end
