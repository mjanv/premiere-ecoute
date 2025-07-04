defmodule PremiereEcoute.Apis.Events do
  @moduledoc false

  defmodule MessageSent do
    @moduledoc false

    @type t :: %__MODULE__{user_id: String.t(), message: String.t()}

    defstruct [:user_id, :message]
  end

  defmodule PollEnded do
    @moduledoc false

    @type t :: %__MODULE__{id: String.t()}

    defstruct [:id]
  end

  defmodule PollStarted do
    @moduledoc false

    @type t :: %__MODULE__{id: String.t()}

    defstruct [:id]
  end

  defmodule PollUpdated do
    @moduledoc false

    @type t :: %__MODULE__{id: String.t()}

    defstruct [:id]
  end
end
