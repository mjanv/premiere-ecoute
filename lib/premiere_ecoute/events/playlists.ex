defmodule PremiereEcoute.Events.LibraryPlaylistAdded do
  @moduledoc """
  Event - Playlist added to user library.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          provider: term()
        }

  use PremiereEcouteCore.Event, fields: [:provider]
end

defmodule PremiereEcoute.Events.LibraryPlaylistDeleted do
  @moduledoc """
  Event - Playlist removed from user library.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          provider: term()
        }

  use PremiereEcouteCore.Event, fields: [:provider]
end
