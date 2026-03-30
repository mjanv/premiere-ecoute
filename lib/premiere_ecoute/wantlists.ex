defmodule PremiereEcoute.Wantlists do
  @moduledoc """
  Context for managing user wantlists.

  Each user has a single default wantlist. Items reference discography records
  (albums, singles, or artists) by FK. The wantlist is created on first use.
  """

  import Ecto.Query

  alias PremiereEcoute.Discography.Single
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
    fk_field = fk_for(type)

    with {:ok, wantlist} <- get_or_create_default(user_id) do
      attrs = Map.merge(%{type: type, wantlist_id: wantlist.id}, %{fk_field => record_id})
      WantlistItem.create_if_not_exists(attrs)
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
    item =
      WantlistItem
      |> join(:inner, [i], w in Wantlist, on: w.id == i.wantlist_id and w.user_id == ^user_id)
      |> where([i], i.id == ^item_id)
      |> Repo.one()

    case item do
      nil -> {:error, :not_found}
      item -> Repo.delete(item) |> then(fn {:ok, i} -> {:ok, i} end)
    end
  end

  @spec remove_item(integer(), :album | :track | :artist, integer()) ::
          {:ok, WantlistItem.t()} | {:error, :not_found}
  def remove_item(user_id, type, record_id) do
    fk_field = fk_for(type)

    item =
      WantlistItem
      |> join(:inner, [i], w in Wantlist, on: w.id == i.wantlist_id and w.user_id == ^user_id)
      |> where([i], field(i, ^fk_field) == ^record_id)
      |> Repo.one()

    case item do
      nil -> {:error, :not_found}
      item -> Repo.delete(item) |> then(fn {:ok, i} -> {:ok, i} end)
    end
  end

  @doc """
  Adds a track from the radio to the user's wantlist by Spotify provider ID.

  Looks up the corresponding Single record by Spotify ID. Returns `{:error, :not_found}`
  if no matching Single exists in the discography.
  """
  @spec add_radio_track(integer(), String.t()) ::
          {:ok, WantlistItem.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def add_radio_track(user_id, spotify_id) do
    Single
    |> where([s], fragment("?->>'spotify' = ?", s.provider_ids, ^spotify_id))
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      single -> add_item(user_id, :track, single.id)
    end
  end

  defp fk_for(:album), do: :album_id
  defp fk_for(:track), do: :single_id
  defp fk_for(:artist), do: :artist_id
end
