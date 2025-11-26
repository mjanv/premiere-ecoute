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

  def documents, do: @documents
  def document(id), do: Enum.find(documents(), &(&1.id == Atom.to_string(id)))
end
