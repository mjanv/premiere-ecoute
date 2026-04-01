defmodule PremiereEcoute.Explorer.Card do
  @moduledoc """
  A semantic card within an Explorer node.

  Cards are the atomic unit of content in the Music Explorer canvas. Each card
  represents a thematic chunk of information about an entity (intro, discography,
  members, history). Content is pre-rendered HTML, optionally annotated with
  entity hotspots by AnnotateCards.
  """

  @type card_type :: :intro | :discography | :members | :history

  @type t :: %__MODULE__{
          id: String.t(),
          type: card_type(),
          title: String.t(),
          content_html: String.t()
        }

  @enforce_keys [:id, :type, :title, :content_html]
  defstruct [:id, :type, :title, :content_html]
end
