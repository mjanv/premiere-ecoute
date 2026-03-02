defmodule PremiereEcoute.Sessions.AlbumPick do
  @moduledoc """
  Album pick entry in a streamer's random selection pool.

  Tracks albums added by the streamer or submitted by viewers that can be
  randomly selected when starting a new listening session.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias PremiereEcoute.Accounts.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          album_id: String.t() | nil,
          name: String.t() | nil,
          artist: String.t() | nil,
          cover_url: String.t() | nil,
          source: :streamer | :viewer,
          submitter: String.t() | nil,
          user_id: integer() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "album_picks" do
    field :album_id, :string
    field :name, :string
    field :artist, :string
    field :cover_url, :string
    field :source, Ecto.Enum, values: [:streamer, :viewer], default: :streamer
    field :submitter, :string

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc "AlbumPick changeset."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(pick, attrs) do
    pick
    |> cast(attrs, [:album_id, :name, :artist, :cover_url, :source, :submitter, :user_id])
    |> validate_required([:album_id, :name, :artist, :user_id, :source])
    |> validate_length(:name, min: 1, max: 500)
    |> validate_length(:artist, min: 1, max: 255)
    |> validate_inclusion(:source, [:streamer, :viewer])
    |> unique_constraint([:user_id, :album_id])
    |> foreign_key_constraint(:user_id)
  end
end
