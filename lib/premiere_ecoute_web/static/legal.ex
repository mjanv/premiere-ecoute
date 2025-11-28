defmodule PremiereEcouteWeb.Static.Legal do
  @moduledoc """
  Legal document publisher.

  Publishes legal documents from markdown files using NimblePublisher, providing access to terms of service, privacy policy, and other legal content.
  """

  use NimblePublisher,
    build: PremiereEcoute.Accounts.LegalDocument,
    from: Application.app_dir(:premiere_ecoute, "priv/legal/*.md"),
    as: :documents,
    highlighters: [:makeup_elixir, :makeup_erlang]

  alias PremiereEcoute.Accounts.LegalDocument

  @doc """
  Returns all legal documents.

  Retrieves the complete list of legal documents parsed from markdown files at compile time.
  """
  @spec documents() :: [LegalDocument.t()]
  def documents, do: @documents

  @doc """
  Retrieves a specific legal document by its ID.

  Returns the legal document matching the given atom ID or nil if not found.
  """
  @spec document(atom()) :: LegalDocument.t() | nil
  def document(id), do: Enum.find(documents(), &(&1.id == Atom.to_string(id)))
end
