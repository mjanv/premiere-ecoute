defmodule PremiereEcoute.Twitch.Reward do
  @moduledoc """
  Represents a Twitch channel point custom reward.
  """

  @type id :: String.t()

  @type t :: %__MODULE__{
          id: id(),
          broadcaster_id: String.t(),
          title: String.t(),
          cost: integer(),
          prompt: String.t() | nil,
          is_enabled: boolean(),
          is_paused: boolean(),
          is_in_stock: boolean(),
          is_user_input_required: boolean()
        }

  defstruct [:id, :broadcaster_id, :title, :cost, :prompt, :is_enabled, :is_paused, :is_in_stock, :is_user_input_required]

  @spec parse(map()) :: t()
  def parse(data) do
    %__MODULE__{
      id: data["id"],
      broadcaster_id: data["broadcaster_id"],
      title: data["title"],
      cost: data["cost"],
      prompt: data["prompt"],
      is_enabled: data["is_enabled"],
      is_paused: data["is_paused"],
      is_in_stock: data["is_in_stock"],
      is_user_input_required: data["is_user_input_required"]
    }
  end
end
