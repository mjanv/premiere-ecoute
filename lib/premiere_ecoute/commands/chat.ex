defmodule PremiereEcoute.Commands.Chat do
  @moduledoc false

  defmodule SendChatCommand do
    @moduledoc false

    @type t :: %__MODULE__{
            broadcaster_id: String.t(),
            user_id: String.t(),
            message_id: String.t(),
            command: String.t(),
            args: [String.t()],
            is_streamer: boolean()
          }

    defstruct [:broadcaster_id, :user_id, :message_id, :command, :args, :is_streamer]
  end
end
