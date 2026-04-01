defmodule PremiereEcoute.Explorer.Node do
  @moduledoc """
  A canvas node in the Music Explorer.

  Represents a single entity (artist or album) on the exploration canvas,
  composed of semantic cards, optional thumbnail, and entity metadata.
  Nodes are pure data structures — no database persistence.
  """

  alias PremiereEcoute.Explorer.Card

  @type entity_type :: :artist | :album | :track

  @type t :: %__MODULE__{
          id: String.t(),
          entity_type: entity_type(),
          entity_id: integer() | nil,
          entity_slug: String.t() | nil,
          label: String.t(),
          subtitle: String.t() | nil,
          thumbnail_url: String.t() | nil,
          provider_ids: map(),
          cards: [Card.t()]
        }

  @enforce_keys [:id, :entity_type, :label, :cards]
  defstruct [:id, :entity_type, :entity_id, :entity_slug, :label, :subtitle, :thumbnail_url, provider_ids: %{}, cards: []]
end
