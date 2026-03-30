defmodule PremiereEcoute.Wantlists.WantlistItem do
  @moduledoc """
  A single entry in a wantlist.

  An item references one discography record — either an album, a single (track),
  or an artist. Exactly one of album_id/single_id/artist_id must be set,
  matching the `type` field.
  """

  use PremiereEcouteCore.Aggregate, identity: [:wantlist_id, :album_id, :single_id, :artist_id]

  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Artist
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Wantlists.Wantlist

  @type item_type :: :album | :track | :artist

  @type t :: %__MODULE__{
          id: integer() | nil,
          type: item_type() | nil,
          album_id: integer() | nil,
          single_id: integer() | nil,
          artist_id: integer() | nil,
          album: Album.t() | Ecto.Association.NotLoaded.t() | nil,
          single: Single.t() | Ecto.Association.NotLoaded.t() | nil,
          artist: Artist.t() | Ecto.Association.NotLoaded.t() | nil,
          wantlist_id: integer() | nil,
          wantlist: Wantlist.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "wantlist_items" do
    field :type, Ecto.Enum, values: [:album, :track, :artist]

    belongs_to :album, Album
    belongs_to :single, Single
    belongs_to :artist, Artist
    belongs_to :wantlist, Wantlist

    timestamps(type: :utc_datetime)
  end

  @doc "WantlistItem changeset."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:type, :album_id, :single_id, :artist_id, :wantlist_id])
    |> validate_required([:type, :wantlist_id])
    |> validate_inclusion(:type, [:album, :track, :artist])
    |> validate_item_reference()
    |> unique_constraint(:album_id, name: :wantlist_items_wantlist_id_album_id_index)
    |> unique_constraint(:single_id, name: :wantlist_items_wantlist_id_single_id_index)
    |> unique_constraint(:artist_id, name: :wantlist_items_wantlist_id_artist_id_index)
    |> foreign_key_constraint(:wantlist_id)
    |> foreign_key_constraint(:album_id)
    |> foreign_key_constraint(:single_id)
    |> foreign_key_constraint(:artist_id)
  end

  defp validate_item_reference(changeset) do
    type = get_field(changeset, :type)

    case type do
      :album -> validate_required(changeset, [:album_id])
      :track -> validate_required(changeset, [:single_id])
      :artist -> validate_required(changeset, [:artist_id])
      _ -> changeset
    end
  end
end
