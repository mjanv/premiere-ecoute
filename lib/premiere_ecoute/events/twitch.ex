defmodule PremiereEcoute.Events.Twitch do
  @moduledoc """
  Twitch stream lifecycle events.
  """

  defmodule StreamStarted do
    @moduledoc """
    Event - Twitch stream started.
    """

    @type t :: %__MODULE__{
            broadcaster_id: String.t(),
            broadcaster_name: String.t(),
            started_at: String.t() | nil
          }

    defstruct [:broadcaster_id, :broadcaster_name, :started_at]
  end

  defmodule StreamEnded do
    @moduledoc """
    Event - Twitch stream ended.
    """

    @type t :: %__MODULE__{
            broadcaster_id: String.t(),
            broadcaster_name: String.t()
          }

    defstruct [:broadcaster_id, :broadcaster_name]
  end

  defmodule RewardRedeemed do
    @moduledoc """
    Event - A viewer redeemed a channel point reward.
    """

    @type t :: %__MODULE__{
            id: String.t(),
            broadcaster_id: String.t(),
            user_id: String.t(),
            user_login: String.t(),
            reward_id: String.t(),
            reward_title: String.t(),
            user_input: String.t() | nil,
            status: String.t(),
            redeemed_at: String.t()
          }

    defstruct [:id, :broadcaster_id, :user_id, :user_login, :reward_id, :reward_title, :user_input, :status, :redeemed_at]
  end
end
