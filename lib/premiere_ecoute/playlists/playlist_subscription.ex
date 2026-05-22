defmodule PremiereEcoute.Playlists.PlaylistSubscription do
  @moduledoc """
  Tracks viewer subscriptions to a library playlist.

  One row per (user, playlist) pair. The `channels` array stores all delivery
  destinations the viewer has opted into (e.g. [:email]). Removing the last
  channel deletes the row entirely.
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Repo

  @type channel :: :email | :notification
  @type t :: %__MODULE__{
          id: integer() | nil,
          library_playlist_id: integer() | nil,
          user_id: binary() | nil,
          channels: [channel()],
          library_playlist: LibraryPlaylist.t() | Ecto.Association.NotLoaded.t() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: NaiveDateTime.t() | nil
        }

  schema "playlist_subscriptions" do
    field :channels, {:array, Ecto.Enum}, values: [:email, :notification, :discord], default: []

    belongs_to :library_playlist, LibraryPlaylist
    belongs_to :user, User

    timestamps(updated_at: false)
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(sub, attrs) do
    sub
    |> cast(attrs, [:library_playlist_id, :user_id, :channels])
    |> validate_required([:library_playlist_id, :user_id, :channels])
    |> unique_constraint([:user_id, :library_playlist_id])
    |> foreign_key_constraint(:library_playlist_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Adds `channel` to the user's subscription for the playlist.

  Creates the subscription row if it does not exist yet. Idempotent: adding a
  channel the user already has is a no-op.
  """
  @spec subscribe(LibraryPlaylist.t(), User.t(), channel()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def subscribe(%LibraryPlaylist{id: playlist_id}, %User{id: user_id}, channel) do
    case Repo.get_by(__MODULE__, library_playlist_id: playlist_id, user_id: user_id) do
      nil ->
        %__MODULE__{}
        |> changeset(%{library_playlist_id: playlist_id, user_id: user_id, channels: [channel]})
        |> Repo.insert()

      sub ->
        if channel in sub.channels do
          {:ok, sub}
        else
          sub
          |> changeset(%{channels: sub.channels ++ [channel]})
          |> Repo.update()
        end
    end
  end

  @doc """
  Removes `channel` from the user's subscription.

  Deletes the row when no channels remain. Returns `{:ok, :deleted}` in that
  case, `{:ok, updated_sub}` when other channels remain, or
  `{:error, :not_found}` when no subscription exists.
  """
  @spec unsubscribe(LibraryPlaylist.t(), User.t(), channel()) ::
          {:ok, t() | :deleted} | {:error, :not_found}
  def unsubscribe(%LibraryPlaylist{id: playlist_id}, %User{id: user_id}, channel) do
    case Repo.get_by(__MODULE__, library_playlist_id: playlist_id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      sub ->
        remaining = List.delete(sub.channels, channel)

        if remaining == [] do
          {:ok, _} = Repo.delete(sub)
          {:ok, :deleted}
        else
          sub |> changeset(%{channels: remaining}) |> Repo.update()
        end
    end
  end

  @doc """
  Returns true if the user has an active subscription via the given channel.
  """
  @spec subscribed?(LibraryPlaylist.t(), User.t(), channel()) :: boolean()
  def subscribed?(%LibraryPlaylist{id: playlist_id}, %User{id: user_id}, channel) do
    case Repo.get_by(__MODULE__, library_playlist_id: playlist_id, user_id: user_id) do
      nil -> false
      sub -> channel in sub.channels
    end
  end

  @doc """
  Returns a MapSet of playlist IDs the user is subscribed to via any channel.

  Single query across all given playlists — use this instead of calling `subscribed?`
  in a loop when building UI state.
  """
  @spec subscribed_playlist_ids(User.t(), [LibraryPlaylist.t()]) :: MapSet.t()
  def subscribed_playlist_ids(%User{id: user_id}, playlists) do
    playlist_ids = Enum.map(playlists, & &1.id)

    from(s in __MODULE__,
      where: s.user_id == ^user_id and s.library_playlist_id in ^playlist_ids,
      select: s.library_playlist_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Returns all users subscribed to the playlist via the given channel.
  """
  @spec list_subscribers(LibraryPlaylist.t(), channel()) :: [User.t()]
  def list_subscribers(%LibraryPlaylist{id: playlist_id}, channel) do
    from(s in __MODULE__,
      join: u in User,
      on: u.id == s.user_id,
      where: s.library_playlist_id == ^playlist_id and ^channel in s.channels,
      select: u
    )
    |> Repo.all()
  end

  @doc """
  Returns the number of distinct subscribers for a playlist across all channels.
  """
  @spec subscriber_count(LibraryPlaylist.t()) :: non_neg_integer()
  def subscriber_count(%LibraryPlaylist{id: playlist_id}) do
    from(s in __MODULE__, where: s.library_playlist_id == ^playlist_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns a map of channel atom => subscriber count for a playlist.

  Only channels with at least one subscriber are included.
  """
  @spec counts_per_channel(LibraryPlaylist.t()) :: %{channel() => non_neg_integer()}
  def counts_per_channel(%LibraryPlaylist{id: playlist_id}) do
    from(s in __MODULE__, where: s.library_playlist_id == ^playlist_id, select: s.channels)
    |> Repo.all()
    |> List.flatten()
    |> Enum.frequencies()
  end
end
