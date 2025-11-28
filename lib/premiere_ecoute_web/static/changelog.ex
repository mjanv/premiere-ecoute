defmodule PremiereEcoute.Changelog.Entry do
  @moduledoc """
  Changelog entry schema.

  Represents a single changelog entry with id, title, date, and body content.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          date: String.t(),
          body: String.t()
        }

  @enforce_keys [:id, :title, :date, :body]
  defstruct [:id, :title, :date, :body]

  @doc """
  Builds a changelog entry from file metadata and content.

  Extracts the entry ID from the filename and combines it with the provided attributes and body to create a structured changelog entry.
  """
  @spec build(Path.t(), map(), String.t()) :: t()
  def build(filename, attrs, body) do
    [id] = filename |> Path.rootname() |> Path.split() |> Enum.take(-1)
    struct!(__MODULE__, [id: id, body: body] ++ Map.to_list(attrs))
  end
end

defmodule PremiereEcouteWeb.Static.Changelog do
  @moduledoc """
  Changelog publisher.

  Publishes changelog entries from markdown files using NimblePublisher, providing access to application version history and release notes.
  """

  use NimblePublisher,
    build: PremiereEcoute.Changelog.Entry,
    from: Application.app_dir(:premiere_ecoute, "priv/changelog/*.md"),
    as: :changelog,
    highlighters: [:makeup_elixir, :makeup_erlang]

  alias PremiereEcoute.Changelog.Entry

  @doc """
  Returns all changelog entries.

  Retrieves the complete list of changelog entries parsed from markdown files at compile time.
  """
  @spec all_entries() :: [Entry.t()]
  def all_entries, do: @changelog

  @doc """
  Retrieves a specific changelog entry by its ID.

  Returns the changelog entry matching the given ID or nil if not found.
  """
  @spec get_entry(String.t()) :: Entry.t() | nil
  def get_entry(id), do: Enum.find(all_entries(), &(&1.id == id))
end
