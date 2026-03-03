defmodule PremiereEcoute.Sessions.AlbumPicks do
  @moduledoc """
  Context for managing a streamer's album pick list.

  Streamers curate a list of albums from which a random one can be selected
  when starting a new listening session. Viewers can also submit albums to
  the list via a public page.
  """

  import Ecto.Query

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.AlbumPick

  @doc """
  Returns all album picks for a user, ordered by most recently added.
  """
  @spec list_for_user(integer()) :: [AlbumPick.t()]
  def list_for_user(user_id) do
    AlbumPick
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Adds an album to the streamer's pick list.

  Silently ignores duplicates (same album already in list).
  Returns `{:ok, pick}` on success or `{:error, changeset}` on failure.
  """
  @spec add_entry(integer(), map()) :: {:ok, AlbumPick.t()} | {:error, Ecto.Changeset.t()} | {:error, :already_exists}
  def add_entry(user_id, %{album_id: album_id} = attrs) do
    attrs =
      attrs
      |> Map.put(:user_id, user_id)
      |> Map.put(:source, :streamer)

    case Repo.insert(AlbumPick.changeset(%AlbumPick{}, attrs)) do
      {:ok, pick} ->
        {:ok, pick}

      {:error, %Ecto.Changeset{errors: [user_id: {_, [{:constraint, :unique} | _]}]} = _cs} ->
        case Repo.get_by(AlbumPick, user_id: user_id, album_id: album_id) do
          nil -> {:error, :already_exists}
          existing -> {:ok, existing}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Adds a viewer-submitted album to the streamer's pick list.

  Returns `{:ok, pick}` on success, `{:error, :already_exists}` if the album
  is already in the list, or `{:error, changeset}` on validation failure.
  """
  @spec add_viewer_entry(integer(), map(), String.t()) ::
          {:ok, AlbumPick.t()} | {:error, Ecto.Changeset.t()} | {:error, :already_exists}
  def add_viewer_entry(user_id, %{album_id: album_id} = attrs, submitter) do
    attrs =
      attrs
      |> Map.put(:user_id, user_id)
      |> Map.put(:source, :viewer)
      |> Map.put(:submitter, submitter)

    case Repo.insert(AlbumPick.changeset(%AlbumPick{}, attrs)) do
      {:ok, pick} ->
        {:ok, pick}

      {:error, %Ecto.Changeset{errors: [user_id: {_, [{:constraint, :unique} | _]}]} = _cs} ->
        case Repo.get_by(AlbumPick, user_id: user_id, album_id: album_id) do
          nil -> {:error, :already_exists}
          _existing -> {:error, :already_exists}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Removes an album pick by id, only if it belongs to the given user.
  """
  @spec remove_entry(integer(), integer()) :: {:ok, AlbumPick.t()} | {:error, :not_found}
  def remove_entry(user_id, pick_id) do
    case Repo.get_by(AlbumPick, id: pick_id, user_id: user_id) do
      nil -> {:error, :not_found}
      pick -> Repo.delete(pick) |> then(fn {:ok, p} -> {:ok, p} end)
    end
  end

  @doc """
  Returns the number of album picks for a user.
  """
  @spec count_for_user(integer()) :: non_neg_integer()
  def count_for_user(user_id) do
    AlbumPick
    |> where([p], p.user_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Removes all album picks for the given user.

  Returns the number of deleted entries.
  """
  @spec clear_all(integer()) :: non_neg_integer()
  def clear_all(user_id) do
    {count, _} =
      AlbumPick
      |> where([p], p.user_id == ^user_id)
      |> Repo.delete_all()

    count
  end

  @doc """
  Returns a random album pick for the given user.

  Returns `nil` if the list is empty.
  """
  @spec random_entry(integer()) :: AlbumPick.t() | nil
  def random_entry(user_id) do
    AlbumPick
    |> where([p], p.user_id == ^user_id)
    |> order_by(fragment("RANDOM()"))
    |> limit(1)
    |> Repo.one()
  end
end
