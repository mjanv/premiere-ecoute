defmodule PremiereEcoute.Playlists.PlaylistRule do
  @moduledoc """
  Schema for managing user playlist rules.

  Playlist rules define which playlists should be used for specific actions
  like saving tracks from extensions. Each user can have one active rule
  per rule type.
  """

  use PremiereEcouteCore.Aggregate

  import Ecto.Query
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Discography.LibraryPlaylist
  alias PremiereEcoute.Repo

  @type t :: %__MODULE__{
          id: integer() | nil,
          rule_type: :save_tracks,
          active: boolean(),
          user: User.t() | Ecto.Association.NotLoaded.t() | nil,
          library_playlist: LibraryPlaylist.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "playlist_rules" do
    field :rule_type, Ecto.Enum, values: [:save_tracks], default: :save_tracks
    field :active, :boolean, default: true

    belongs_to :user, User
    belongs_to :library_playlist, LibraryPlaylist

    timestamps()
  end

  @doc """
  Creates changeset for playlist rule with user and playlist validation.

  Validates rule_type (save_tracks), user_id, library_playlist_id, and enforces unique constraint ensuring only one active rule per user per rule type.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(playlist_rule, attrs) do
    playlist_rule
    |> cast(attrs, [:rule_type, :active, :user_id, :library_playlist_id])
    |> validate_required([:rule_type, :user_id, :library_playlist_id])
    |> validate_inclusion(:rule_type, [:save_tracks])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:library_playlist_id)
    |> unique_constraint([:user_id, :rule_type],
      where: "active = true",
      message: "only one active rule per user per rule type"
    )
  end

  @doc """
  Sets the active save_tracks playlist for a user.

  Deactivates any existing save_tracks rule and creates a new active one.
  """
  @spec set_save_tracks_playlist(User.t(), LibraryPlaylist.t()) :: {:ok, t()} | {:error, term()}
  def set_save_tracks_playlist(%User{id: user_id}, %LibraryPlaylist{id: playlist_id}) do
    Repo.transaction(fn ->
      # Deactivate any existing active save_tracks rules for this user
      from(pr in __MODULE__,
        where: pr.user_id == ^user_id and pr.rule_type == :save_tracks and pr.active == true
      )
      |> Repo.update_all(set: [active: false, updated_at: DateTime.utc_now()])

      # Create new active rule
      %__MODULE__{}
      |> changeset(%{
        rule_type: :save_tracks,
        active: true,
        user_id: user_id,
        library_playlist_id: playlist_id
      })
      |> Repo.insert!()
    end)
  end

  @doc """
  Gets the active save_tracks playlist for a user.

  Returns the LibraryPlaylist if an active rule exists, nil otherwise.
  """
  @spec get_save_tracks_playlist(User.t()) :: LibraryPlaylist.t() | nil
  def get_save_tracks_playlist(%User{id: user_id}) do
    query =
      from pr in __MODULE__,
        join: lp in assoc(pr, :library_playlist),
        where: pr.user_id == ^user_id and pr.rule_type == :save_tracks and pr.active == true,
        select: lp

    Repo.one(query)
  end

  @doc """
  Deactivates the save_tracks rule for a user.

  Sets the active flag to false for any active save_tracks rules.
  """
  @spec deactivate_save_tracks_playlist(User.t()) :: {integer(), nil | [term()]}
  def deactivate_save_tracks_playlist(%User{id: user_id}) do
    from(pr in __MODULE__,
      where: pr.user_id == ^user_id and pr.rule_type == :save_tracks and pr.active == true
    )
    |> Repo.update_all(set: [active: false, updated_at: DateTime.utc_now()])
  end

  @doc """
  Gets the active save_tracks rule (with preloaded playlist) for a user.

  Returns the PlaylistRule struct with preloaded library_playlist if exists, nil otherwise.
  """
  @spec get_save_tracks_rule(User.t()) :: t() | nil
  def get_save_tracks_rule(%User{id: user_id}) do
    from(pr in __MODULE__,
      where: pr.user_id == ^user_id and pr.rule_type == :save_tracks and pr.active == true,
      preload: [:library_playlist]
    )
    |> Repo.one()
  end
end
