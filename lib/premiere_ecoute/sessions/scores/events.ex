defmodule PremiereEcoute.Sessions.Scores.Events do
  @moduledoc false

  defmodule MessageSent do
    @moduledoc false

    @type t :: %__MODULE__{broadcaster_id: String.t(), user_id: String.t(), message: String.t()}

    defstruct [:broadcaster_id, :user_id, :message]
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
