defmodule PremiereEcoute.Events.CollectionCreated do
  @moduledoc """
  Event - Collection session created.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil
        }

  use PremiereEcouteCore.Event
end

defmodule PremiereEcoute.Events.CollectionDeleted do
  @moduledoc """
  Event - Collection session deleted.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil
        }

  use PremiereEcouteCore.Event
end
