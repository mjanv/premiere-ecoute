defmodule PremiereEcoute.Accounts.User.Follow do
  @moduledoc """
  User Follow

  Manages follow relationships between users and streamers in the system. This module handles the creation and removal of follow connections, ensuring proper validation of user roles and maintaining data integrity through unique constraints.

  The module enforces that only users with the `:streamer` role can be followed, preventing invalid follow relationships and maintaining the application's user hierarchy.
  """

  use PremiereEcoute.Core.Entity,
    root: [:user],
    json: [:user, :streamer]

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Events.ChannelFollowed
  alias PremiereEcoute.Events.ChannelUnfollowed

  @type t :: %__MODULE__{
          user_id: String.t(),
          streamer_id: String.t(),
          followed_at: NaiveDateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "user_follows" do
    belongs_to :user, User
    belongs_to :streamer, User

    field :followed_at, :naive_datetime

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates and validates a follow relationship changeset.

  Validates the follow relationship by ensuring both user_id and streamer_id are present, verifying that the target user has the streamer role, and enforcing uniqueness constraints to prevent duplicate follows. The changeset includes custom validation to check the streamer_role attribute passed in the attrs map.
  """
  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:user_id, :streamer_id, :followed_at])
    |> validate_required([:user_id, :streamer_id])
    |> validate_change(:streamer_id, fn :streamer_id, _ ->
      case Map.get(attrs, :streamer_role) do
        :streamer -> []
        _ -> [streamer: "must have the streamer role"]
      end
    end)
    |> unique_constraint([:user_id, :streamer_id])
  end

  @doc """
  Creates a follow relationship between a user and a streamer.

  Establishes a follow connection by creating a new Follow record with the provided user and streamer entities. The function automatically extracts the necessary IDs and role information to create the relationship through the changeset validation process.
  """
  def follow(user, streamer, opts \\ %{}) do
    %{user_id: user.id, streamer_id: streamer.id, streamer_role: streamer.role, followed_at: opts[:followed_at]}
    |> create()
    |> EventStore.ok("user", fn follow -> %ChannelFollowed{id: follow.user_id, streamer_id: follow.streamer_id} end)
  end

  @doc """
  Removes an existing follow relationship between a user and a streamer.

  Attempts to find and delete the follow relationship between the specified user and streamer. If the relationship doesn't exist, returns an error changeset with an appropriate message. Successfully removes the follow record when found, effectively unfollowing the streamer.
  """
  def unfollow(%User{} = user, %User{} = streamer) do
    case get_by(user_id: user.id, streamer_id: streamer.id) do
      nil ->
        %__MODULE__{}
        |> change(%{user_id: user.id, streamer_id: streamer.id})
        |> add_error(:streamer, "You are not following this streamer")
        |> then(fn changeset -> {:error, changeset} end)

      follow ->
        Repo.delete(follow)
    end
    |> EventStore.ok("user", fn unfollow -> %ChannelUnfollowed{id: unfollow.user_id, streamer_id: unfollow.streamer_id} end)
  end

  def discover_follows(%User{id: id}) do
    from(u in User,
      where: u.role == :streamer,
      where: u.id != ^id,
      where: u.id not in subquery(from f in __MODULE__, where: f.user_id == ^id, select: f.streamer_id),
      order_by: [asc: :id]
    )
    |> Repo.all()
  end
end
