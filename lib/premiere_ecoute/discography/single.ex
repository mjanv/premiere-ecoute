defmodule PremiereEcoute.Discography.Single do
  @moduledoc """
  Single track in the discography system.

  A single is a standalone track (not tied to an album or playlist) that can be used
  in a lightweight listening session. Identified by provider and track ID.
  """

  use PremiereEcouteCore.Aggregate,
    identity: [:provider, :track_id],
    json: [:id, :name, :artist, :cover_url, :duration_ms]

  @type t :: %__MODULE__{
          id: integer() | nil,
          provider: :spotify,
          track_id: String.t() | nil,
          name: String.t() | nil,
          artist: String.t() | nil,
          duration_ms: integer() | nil,
          cover_url: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "singles" do
    field :provider, Ecto.Enum, values: [:spotify]
    field :track_id, :string
    field :name, :string
    field :artist, :string
    field :duration_ms, :integer
    field :cover_url, :string

    timestamps(type: :utc_datetime)
  end

  @doc "Creates changeset for single validation."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(single, attrs) do
    single
    |> cast(attrs, [:provider, :track_id, :name, :artist, :duration_ms, :cover_url])
    |> validate_required([:provider, :track_id, :name, :artist])
    |> validate_inclusion(:provider, [:spotify])
    |> unique_constraint([:provider, :track_id])
  end
end
