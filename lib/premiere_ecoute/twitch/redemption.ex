defmodule PremiereEcoute.Twitch.Redemption do
  @moduledoc """
  Represents a Twitch channel point reward redemption.
  """

  @type id :: String.t()
  @type status :: :unfulfilled | :fulfilled | :canceled

  @type t :: %__MODULE__{
          id: id(),
          broadcaster_id: String.t(),
          user_id: String.t(),
          user_login: String.t(),
          reward_id: String.t(),
          reward_title: String.t(),
          user_input: String.t() | nil,
          status: status(),
          redeemed_at: String.t()
        }

  defstruct [:id, :broadcaster_id, :user_id, :user_login, :reward_id, :reward_title, :user_input, :status, :redeemed_at]

  @spec parse(map()) :: t()
  def parse(data) do
    %__MODULE__{
      id: data["id"],
      broadcaster_id: data["broadcaster_id"],
      user_id: data["user_id"],
      user_login: data["user_login"],
      reward_id: data["reward"]["id"],
      reward_title: data["reward"]["title"],
      user_input: data["user_input"],
      status: parse_status(data["status"]),
      redeemed_at: data["redeemed_at"]
    }
  end

  defp parse_status("UNFULFILLED"), do: :unfulfilled
  defp parse_status("unfulfilled"), do: :unfulfilled
  defp parse_status("FULFILLED"), do: :fulfilled
  defp parse_status("fulfilled"), do: :fulfilled
  defp parse_status("CANCELED"), do: :canceled
  defp parse_status("canceled"), do: :canceled
end
