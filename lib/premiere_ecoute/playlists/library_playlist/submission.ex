defmodule PremiereEcoute.Playlists.LibraryPlaylist.Submission do
  @moduledoc """
  Tracks viewer track submissions to a library playlist.

  Records which authenticated user submitted which Spotify track to a given
  playlist, enabling per-viewer submission limits and submitter attribution
  in the track list.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Repo

  @type t :: %__MODULE__{
          id: integer() | nil,
          library_playlist_id: integer() | nil,
          user_id: binary() | nil,
          provider_id: String.t() | nil,
          library_playlist: LibraryPlaylist.t() | Ecto.Association.NotLoaded.t() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: NaiveDateTime.t() | nil
        }

  schema "library_playlist_submissions" do
    field :provider_id, :string

    belongs_to :library_playlist, LibraryPlaylist
    belongs_to :user, User

    timestamps(updated_at: false)
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(submission, attrs) do
    submission
    |> cast(attrs, [:library_playlist_id, :user_id, :provider_id])
    |> validate_required([:library_playlist_id, :user_id, :provider_id])
    |> unique_constraint([:library_playlist_id, :user_id, :provider_id],
      name: :library_playlist_submissions_library_playlist_id_user_id_provid
    )
    |> foreign_key_constraint(:library_playlist_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Records a viewer's track submission to a playlist.
  """
  @spec create(LibraryPlaylist.t(), User.t(), String.t()) ::
          {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(%LibraryPlaylist{id: playlist_id}, %User{id: user_id}, provider_id) do
    %__MODULE__{}
    |> changeset(%{
      library_playlist_id: playlist_id,
      user_id: user_id,
      provider_id: provider_id
    })
    |> Repo.insert()
  end

  @doc """
  Returns the number of submissions made by a user for a playlist.
  """
  @spec count_for_viewer(LibraryPlaylist.t(), User.t()) :: non_neg_integer()
  def count_for_viewer(%LibraryPlaylist{id: playlist_id}, %User{id: user_id}) do
    from(s in __MODULE__,
      where: s.library_playlist_id == ^playlist_id and s.user_id == ^user_id
    )
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns all submissions made by a user for a playlist, ordered oldest first.
  """
  @spec list_for_viewer(LibraryPlaylist.t(), User.t()) :: [t()]
  def list_for_viewer(%LibraryPlaylist{id: playlist_id}, %User{id: user_id}) do
    from(s in __MODULE__,
      where: s.library_playlist_id == ^playlist_id and s.user_id == ^user_id,
      order_by: [asc: s.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Deletes a single submission record owned by the given user.

  Returns {:ok, submission} if found and deleted, {:error, :not_found} if the
  submission does not belong to that user.
  """
  @spec delete_for_viewer(LibraryPlaylist.t(), User.t(), String.t()) ::
          {:ok, t()} | {:error, :not_found}
  def delete_for_viewer(%LibraryPlaylist{id: playlist_id}, %User{id: user_id}, provider_id) do
    case Repo.get_by(__MODULE__,
           library_playlist_id: playlist_id,
           user_id: user_id,
           provider_id: provider_id
         ) do
      nil -> {:error, :not_found}
      submission -> Repo.delete(submission)
    end
  end

  @doc """
  Returns submissions for a playlist as a map of provider_id => app username.

  Used to attribute submitted tracks to their submitters in the track list,
  overriding the raw Spotify user_id when a submission record exists.
  """
  @spec submitters_map(LibraryPlaylist.t()) :: %{String.t() => String.t()}
  def submitters_map(%LibraryPlaylist{id: playlist_id}) do
    from(s in __MODULE__,
      join: u in assoc(s, :user),
      where: s.library_playlist_id == ^playlist_id,
      select: {s.provider_id, u.username}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Deletes submission records for tracks no longer present in the playlist.

  Called on playlist load to reconcile stale entries when tracks have been
  removed directly via Spotify.
  """
  @spec delete_stale(LibraryPlaylist.t(), [String.t()]) :: non_neg_integer()
  # AIDEV-NOTE: Guard against empty list — SQL `NOT IN []` would delete every row for the playlist,
  # which would wipe all submissions on a transient empty Spotify response.
  def delete_stale(_playlist, []), do: 0

  def delete_stale(%LibraryPlaylist{id: playlist_id}, live_track_ids) do
    {count, _} =
      from(s in __MODULE__,
        where: s.library_playlist_id == ^playlist_id and s.provider_id not in ^live_track_ids
      )
      |> Repo.delete_all()

    count
  end
end
