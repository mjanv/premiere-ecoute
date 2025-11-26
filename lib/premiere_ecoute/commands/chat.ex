defmodule PremiereEcoute.Commands.Chat do
  @moduledoc """
  Chat command definitions.
  """

  defmodule SendChatCommand do
    @moduledoc """
    Command - Send chat command.

    Represents a chat command triggered by a user in Twitch chat with command name, arguments, and context about the broadcaster and user.
    """

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
