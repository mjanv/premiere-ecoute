defmodule PremiereEcoute.Accounts.User.Consent do
  @moduledoc """
  User consent entity.

  Tracks user acceptance or refusal of legal documents (privacy/cookies/terms) with version tracking, publishes ConsentGiven events, and validates user compliance with required documents.
  """

  use PremiereEcouteCore.Aggregate.Entity,
    identity: [:document, :user_id]

  alias PremiereEcoute.Accounts.LegalDocument
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Events.ConsentGiven
  alias PremiereEcoute.Events.Store

  schema "user_consents" do
    field :document, Ecto.Enum, values: [:privacy, :cookies, :terms]
    field :version, :string
    field :accepted, :boolean

    belongs_to :user, PremiereEcoute.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(entity, attrs) do
    entity
    |> cast(attrs, [:document, :version, :accepted, :user_id])
    |> validate_required([:document, :version, :accepted, :user_id])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :document])
  end

  @doc "Accept legal document(s) for a user. Creates new consent or updates existing one to accepted."
  def accept(%User{id: id}, %LegalDocument{id: document, version: version}) do
    case get_by(user_id: id, document: document) do
      nil -> create(%{user_id: id, document: String.to_existing_atom(document), version: version, accepted: true})
      consent -> __MODULE__.update(consent, %{version: version, accepted: true})
    end
    |> Store.ok("user", fn consent ->
      %ConsentGiven{id: consent.user_id, document: consent.document, version: consent.version, accepted: consent.accepted}
    end)
  end

  def accept(%User{id: id}, documents) when is_map(documents) do
    documents
    |> Map.values()
    |> Enum.reduce(
      Ecto.Multi.new(),
      fn %LegalDocument{id: document, version: version}, multi ->
        multi
        |> Ecto.Multi.insert(
          {:consent, document},
          changeset(%__MODULE__{}, %{user_id: id, document: String.to_existing_atom(document), version: version, accepted: true})
        )
        |> Ecto.Multi.run(
          {:event, document},
          fn _repo, _ ->
            event = %ConsentGiven{id: id, document: String.to_existing_atom(document), version: version, accepted: true}
            Store.append(event, stream: "user")
            {:ok, event}
          end
        )
      end
    )
    |> Repo.transact()
  end

  @doc """
  Refuse a legal document for a user. Creates new consent or updates existing one to refused.
  """
  def refuse(%User{id: id}, %LegalDocument{id: document, version: version}) do
    case get_by(user_id: id, document: document) do
      nil -> create(%{user_id: id, document: String.to_existing_atom(document), version: version, accepted: false})
      consent -> __MODULE__.update(consent, %{version: version, accepted: false})
    end
    |> Store.ok("user", fn consent ->
      %ConsentGiven{id: consent.user_id, document: consent.document, version: consent.version, accepted: consent.accepted}
    end)
  end

  @doc """
  Check if user has approved all required legal documents with correct versions.
  Returns true if all documents are accepted with matching versions, false otherwise.
  """
  def approval(%User{id: user_id}, documents) when is_map(documents) do
    Repo.one(
      from c in __MODULE__,
        where: c.user_id == ^user_id and c.accepted == true,
        where:
          ^(documents
            |> Map.values()
            |> Enum.reduce(false, fn %LegalDocument{id: id, version: version}, acc ->
              dynamic([c], ^acc or ^dynamic([c], c.document == ^id and c.version == ^version))
            end)),
        select: count(c.id) == ^map_size(documents)
    )
  end
end
