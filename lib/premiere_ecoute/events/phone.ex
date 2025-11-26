defmodule PremiereEcoute.Events.Phone do
  @moduledoc """
  Phone events.
  """

  defmodule SmsMessageSent do
    @moduledoc """
    Event - SMS message sent.

    Represents SMS message sending with sender phone number, country, and message content for tracking purposes.
    """

    @type t :: %__MODULE__{
            from: String.t(),
            country: String.t(),
            message: String.t()
          }

    defstruct [:from, :country, :message]
  end
end
