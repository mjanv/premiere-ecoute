defmodule PremiereEcoute.Accounts.User.Follow do
  @moduledoc """
  User Follow

  Manages follow relationships between any two users in the system.
  """

  use PremiereEcouteCore.Aggregate.Entity,
    root: [:follower],
    json: [:follower, :followed]

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Events.ChannelFollowed
  alias PremiereEcoute.Events.ChannelUnfollowed
  alias PremiereEcoute.Events.Store

  @type t :: %__MODULE__{
          follower_id: integer() | nil,
          followed_id: integer() | nil,
          followed_at: NaiveDateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "user_follows" do
    belongs_to :follower, User
    belongs_to :followed, User

    field :followed_at, :naive_datetime

    timestamps(type: :utc_datetime)
  end

  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:follower_id, :followed_id, :followed_at])
    |> validate_required([:follower_id, :followed_id])
    |> validate_change(:follower_id, fn :follower_id, follower_id ->
      if Map.get(attrs, :followed_id) == follower_id do
        [follower_id: "cannot follow yourself"]
      else
        []
      end
    end)
    |> unique_constraint([:follower_id, :followed_id])
  end

  @doc "Creates a follow relationship between two users."
  @spec follow(User.t(), User.t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def follow(%User{id: follower_id} = follower, %User{id: followed_id} = followed) do
    with {:ok, follow} <- create(%{follower_id: follower_id, followed_id: followed_id, followed_at: NaiveDateTime.utc_now()}) do
      Store.append(%ChannelFollowed{id: follower.id, followed_id: followed.id}, stream: "user")
      {:ok, follow}
    end
  end

  @doc "Removes an existing follow relationship."
  @spec unfollow(User.t(), User.t()) :: {:ok, t()} | {:error, :not_found}
  def unfollow(%User{id: follower_id} = follower, %User{id: followed_id} = followed) do
    case get_by(follower_id: follower_id, followed_id: followed_id) do
      nil ->
        {:error, :not_found}

      follow ->
        with {:ok, deleted} <- Repo.delete(follow) do
          Store.append(%ChannelUnfollowed{id: follower.id, followed_id: followed.id}, stream: "user")
          {:ok, deleted}
        end
    end
  end

  @doc "Returns true if follower is following followed."
  @spec following?(integer(), integer()) :: boolean()
  def following?(follower_id, followed_id) do
    Repo.exists?(from f in __MODULE__, where: f.follower_id == ^follower_id and f.followed_id == ^followed_id)
  end

  @doc "Returns the number of followers for a user."
  @spec follower_count(integer()) :: integer()
  def follower_count(user_id) do
    from(f in __MODULE__, where: f.followed_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  @doc "Returns the list of users that the given user follows."
  @spec following_list(integer()) :: list(User.t())
  def following_list(user_id) do
    from(u in User,
      join: f in __MODULE__,
      on: f.followed_id == u.id and f.follower_id == ^user_id,
      order_by: [asc: f.inserted_at],
      preload: [:twitch]
    )
    |> Repo.all()
  end

  @doc "Returns users that the given user is not currently following, excluding themselves."
  @spec discover_follows(User.t()) :: list(User.t())
  def discover_follows(%User{id: id}) do
    from(u in User,
      where: u.id != ^id,
      where: u.id not in subquery(from f in __MODULE__, where: f.follower_id == ^id, select: f.followed_id),
      order_by: [asc: :id],
      preload: [:twitch]
    )
    |> Repo.all()
  end
end
