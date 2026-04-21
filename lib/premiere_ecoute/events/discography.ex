defmodule PremiereEcoute.Events.ArtistAdded do
  @moduledoc """
  Event - Artist added to discography.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil
        }

  use PremiereEcouteCore.Event, fields: [:name]
end

defmodule PremiereEcoute.Events.AlbumAdded do
  @moduledoc """
  Event - Album added to discography.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          artist: String.t() | nil
        }

  use PremiereEcouteCore.Event, fields: [:name, :artist]
end
