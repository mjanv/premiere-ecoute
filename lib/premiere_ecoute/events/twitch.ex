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
end
