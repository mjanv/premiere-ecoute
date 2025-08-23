defmodule PremiereEcoute.Events.Phone do
  @moduledoc false

  defmodule SmsMessageSent do
    @moduledoc false

    @type t :: %__MODULE__{
            from: String.t(),
            country: String.t(),
            message: String.t()
          }

    defstruct [:from, :country, :message]
  end
end
