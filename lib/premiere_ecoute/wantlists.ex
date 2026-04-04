defmodule PremiereEcoute.Wantlists do
  @moduledoc """
  Context for managing user wantlists.

  Each user has a single default wantlist. Items reference discography records
  (albums, singles, or artists) by FK. The wantlist is created on first use.
  """

  import Ecto.Query

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Discography.Album
  alias PremiereEcoute.Discography.Services.EnrichDiscography
  alias PremiereEcoute.Discography.Single
  alias PremiereEcoute.Events.AddedToWantlist
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Wantlists.Wantlist
  alias PremiereEcoute.Wantlists.WantlistItem

  @doc """
  Returns the default wantlist for a user, creating it if it does not exist.
  """
  @spec get_or_create_default(integer()) :: {:ok, Wantlist.t()} | {:error, Ecto.Changeset.t()}
  def get_or_create_default(user_id) do
    case Repo.get_by(Wantlist, user_id: user_id) do
      nil ->
        %Wantlist{}
        |> Wantlist.changeset(%{user_id: user_id})
        |> Repo.insert()

      wantlist ->
        {:ok, wantlist}
    end
  end

  @doc """
  Returns the user's wantlist with all items preloaded, or `nil` if none exists.

  Items are preloaded with their referenced album, single, or artist record,
  ordered by most recently added.
  """
  @spec get_wantlist(integer()) :: Wantlist.t() | nil
  def get_wantlist(user_id) do
    Wantlist.get_by(user_id: user_id)
  end

  @doc """
  Adds an item to the user's wantlist.

  `type` is `:album`, `:track`, or `:artist`. `record_id` is the FK of the
  corresponding discography record.

  Returns `{:ok, item}` on success. Silently returns `{:ok, item}` if the item
  is already in the wantlist (idempotent).
  """
  @spec add_item(integer(), :album | :track | :artist, integer()) ::
          {:ok, WantlistItem.t()} | {:error, Ecto.Changeset.t()}
  def add_item(user_id, type, record_id) do
    with {:ok, wantlist} <- get_or_create_default(user_id) do
      Map.merge(%{type: type, wantlist_id: wantlist.id}, %{fk_for(type) => record_id})
      |> WantlistItem.create_if_not_exists()
      |> Store.ok("wantlist", fn _item -> %AddedToWantlist{id: user_id, type: Atom.to_string(type), record_id: record_id} end)
    end
  end

  @doc """
  Returns whether an item of the given type is already in the user's wantlist.
  """
  @spec in_wantlist?(integer(), :album | :track | :artist, integer()) :: boolean()
  def in_wantlist?(user_id, type, record_id) do
    fk_field = fk_for(type)

    WantlistItem
    |> join(:inner, [i], w in Wantlist, on: w.id == i.wantlist_id and w.user_id == ^user_id)
    |> where([i], field(i, ^fk_field) == ^record_id)
    |> Repo.exists?()
  end

  @doc """
  Removes a wantlist item by id, only if it belongs to the given user's wantlist.

  Returns `{:ok, item}` on success or `{:error, :not_found}` if the item does not exist.
  """
  @spec remove_item(integer(), integer()) :: {:ok, WantlistItem.t()} | {:error, :not_found}
  def remove_item(user_id, item_id) do
    WantlistItem
    |> join(:inner, [i], w in Wantlist, on: w.id == i.wantlist_id and w.user_id == ^user_id)
    |> where([i], i.id == ^item_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      item -> Repo.delete(item) |> then(fn {:ok, i} -> {:ok, i} end)
    end
  end

  @spec remove_item(integer(), :album | :track | :artist, integer()) ::
          {:ok, WantlistItem.t()} | {:error, :not_found}
  def remove_item(user_id, type, record_id) do
    fk_field = fk_for(type)

    WantlistItem
    |> join(:inner, [i], w in Wantlist, on: w.id == i.wantlist_id and w.user_id == ^user_id)
    |> where([i], field(i, ^fk_field) == ^record_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      item -> Repo.delete(item) |> then(fn {:ok, i} -> {:ok, i} end)
    end
  end

  @doc """
  Returns a MapSet of Spotify track IDs that are already in the user's wantlist,
  either as singles or via an album track.
  """
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

  @doc """
  Adds a track from the radio to the user's wantlist by Spotify provider ID.

  Looks up the corresponding Single or Album record by Spotify ID. If none exists,
  fetches the track from Spotify and creates the appropriate discography record:
  - a Single if the Spotify track is a standalone single
  - an Album if the Spotify track belongs to an album

  Returns `{:error, term()}` if the Spotify API call or database insertion fails.
  """
  @spec add_radio_track(integer(), String.t()) ::
          {:ok, WantlistItem.t()} | {:error, term()}
  def add_radio_track(user_id, spotify_id) do
    case find_existing_record(spotify_id) do
      {:single, single} -> add_item(user_id, :track, single.id)
      {:album, album} -> add_item(user_id, :album, album.id)
      :not_found -> create_and_add(user_id, spotify_id)
    end
  end

  # AIDEV-NOTE: checks both Single and Album tables for an existing record matching the Spotify track ID
  defp find_existing_record(spotify_id) do
    single =
      Single
      |> where([s], fragment("?->>'spotify' = ?", s.provider_ids, ^spotify_id))
      |> Repo.one()

    if single do
      {:single, single}
    else
      album =
        Album
        |> join(:inner, [a], t in assoc(a, :tracks))
        |> where([_a, t], fragment("?->>'spotify' = ?", t.provider_ids, ^spotify_id))
        |> Repo.one()

      if album, do: {:album, album}, else: :not_found
    end
  end

  # AIDEV-NOTE: fetches track from Spotify and creates either a Single or Album in the discography
  defp create_and_add(user_id, spotify_id) do
    case Apis.spotify().get_single(spotify_id) do
      {:ok, single} ->
        with {:ok, single} <- Single.create_if_not_exists(single) do
          add_item(user_id, :track, single.id)
        end

      {:error, :no_track_found} ->
        with {:ok, track} <- Apis.spotify().get_track(spotify_id),
             album_spotify_id <- Map.get(track, :album_spotify_id),
             {:ok, album} <- EnrichDiscography.create_album(album_spotify_id) do
          add_item(user_id, :album, album.id)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fk_for(:album), do: :album_id
  defp fk_for(:track), do: :single_id
  defp fk_for(:artist), do: :artist_id
end
