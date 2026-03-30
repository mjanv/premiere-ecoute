defmodule PremiereEcoute.Events.AddedToWantlist do
  @moduledoc """
  Event - Item added to user wantlist.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: String.t() | nil,
          record_id: integer() | nil
        }

  use PremiereEcouteCore.Event, fields: [:type, :record_id]
end
