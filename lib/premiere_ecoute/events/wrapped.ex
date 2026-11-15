defmodule PremiereEcoute.Events.WrappedViewed do
  @moduledoc """
  Event - A viewer opened their Wrapped. `id` is the user id, `render` the render it was played with.
  """

  @type t :: %__MODULE__{id: integer() | nil, year: integer() | nil, render: String.t() | nil}

  use PremiereEcouteCore.Event, fields: [:year, :render]
end

defmodule PremiereEcoute.Events.WrappedShared do
  @moduledoc """
  Event - A viewer shared their Wrapped. `id` is the user id, `render` the render it was played with.
  """

  @type t :: %__MODULE__{id: integer() | nil, year: integer() | nil, render: String.t() | nil}

  use PremiereEcouteCore.Event, fields: [:year, :render]
end
