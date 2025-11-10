defmodule PremiereEcoute.Events.Chat do
  @moduledoc false

  defmodule MessageSent do
    @moduledoc false

    @type t :: %__MODULE__{
            broadcaster_id: String.t(),
            user_id: String.t(),
            message: String.t(),
            is_streamer: boolean()
          }

    defstruct [:broadcaster_id, :user_id, :message, :is_streamer]
  end

  defmodule CommandSent do
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

  defmodule PollEnded do
    @moduledoc false

    @type t :: %__MODULE__{id: String.t(), title: String.t(), votes: map()}

    defstruct [:id, :title, :votes]
  end

  defmodule PollStarted do
    @moduledoc false

    @type t :: %__MODULE__{id: String.t(), votes: map()}

    defstruct [:id, :title, :votes]
  end

  defmodule PollUpdated do
    @moduledoc false

    @type t :: %__MODULE__{id: String.t(), votes: map()}

    defstruct [:id, :votes]
  end
end
