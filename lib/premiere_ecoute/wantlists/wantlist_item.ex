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
  alias PremiereEcoute.Events.AddedToWantlist
  alias PremiereEcoute.Events.RemovedFromWantlist
  alias PremiereEcoute.Wantlists.Wantlist
  alias PremiereEcoute.Wantlists.WantlistItem

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

  @spec add(integer(), item_type(), integer()) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
  def add(user_id, type, record_id) do
    with {:ok, wantlist} <- Wantlist.get_or_create(user_id) do
      Map.merge(%{type: type, wantlist_id: wantlist.id}, %{fk_for(type) => record_id})
      |> WantlistItem.create_if_not_exists()
      |> Store.ok("wantlist", fn _item ->
        %AddedToWantlist{id: user_id, type: Atom.to_string(type), record_id: record_id}
      end)
    end
  end

  @spec exists?(integer(), item_type(), integer()) :: boolean()
  def exists?(user_id, type, record_id) do
    fk_field = fk_for(type)

    WantlistItem
    |> join(:inner, [i], w in Wantlist, on: w.id == i.wantlist_id and w.user_id == ^user_id)
    |> where([i], field(i, ^fk_field) == ^record_id)
    |> Repo.exists?()
  end

  @spec remove(integer(), integer()) :: {:ok, t()} | {:error, :not_found}
  def remove(user_id, item_id) do
    WantlistItem
    |> join(:inner, [i], w in Wantlist, on: w.id == i.wantlist_id and w.user_id == ^user_id)
    |> where([i], i.id == ^item_id)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      item ->
        item
        |> Repo.delete()
        |> Store.ok("wantlist", fn i ->
          %RemovedFromWantlist{id: user_id, type: Atom.to_string(i.type), record_id: i.album_id || i.single_id || i.artist_id}
        end)
    end
  end

  @spec remove(integer(), item_type(), integer()) :: {:ok, t()} | {:error, :not_found}
  def remove(user_id, type, record_id) do
    fk_field = fk_for(type)

    WantlistItem
    |> join(:inner, [i], w in Wantlist, on: w.id == i.wantlist_id and w.user_id == ^user_id)
    |> where([i], field(i, ^fk_field) == ^record_id)
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      item ->
        item
        |> Repo.delete()
        |> Store.ok("wantlist", fn _ ->
          %RemovedFromWantlist{id: user_id, type: Atom.to_string(type), record_id: record_id}
        end)
    end
  end

  @spec wantlisted_spotify_ids(integer(), [String.t()]) :: MapSet.t(String.t())
  def wantlisted_spotify_ids(_user_id, []), do: MapSet.new()

  def wantlisted_spotify_ids(user_id, spotify_ids) do
    single_ids =
      Single
      |> join(:inner, [s], wi in WantlistItem, on: wi.single_id == s.id)
      |> join(:inner, [_s, wi], w in Wantlist, on: w.id == wi.wantlist_id and w.user_id == ^user_id)
      |> where([s], fragment("?->>'spotify'", s.provider_ids) in ^spotify_ids)
      |> select([s], fragment("?->>'spotify'", s.provider_ids))
      |> Repo.all()

    album_ids =
      Album
      |> join(:inner, [a], t in assoc(a, :tracks))
      |> join(:inner, [a], wi in WantlistItem, on: wi.album_id == a.id)
      |> join(:inner, [_a, _t, wi], w in Wantlist, on: w.id == wi.wantlist_id and w.user_id == ^user_id)
      |> where([_a, t], fragment("?->>'spotify'", t.provider_ids) in ^spotify_ids)
      |> select([_a, t], fragment("?->>'spotify'", t.provider_ids))
      |> Repo.all()

    MapSet.new(single_ids ++ album_ids)
  end

  defp fk_for(:album), do: :album_id
  defp fk_for(:track), do: :single_id
  defp fk_for(:artist), do: :artist_id

  defp validate_item_reference(changeset) do
    case get_field(changeset, :type) do
      :album -> validate_required(changeset, [:album_id])
      :track -> validate_required(changeset, [:single_id])
      :artist -> validate_required(changeset, [:artist_id])
      _ -> changeset
    end
  end
end
