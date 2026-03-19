defmodule PremiereEcoute.Notifications.Notification do
  @moduledoc """
  Schema for user_notifications table.

  Persists every notification before any delivery attempt so offline users
  see missed notifications on their next visit.
  """

  use PremiereEcouteCore.Aggregate,
    json: [:id, :user_id, :type, :data, :read_at, :inserted_at]

  alias PremiereEcoute.Accounts.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          user: entity(User.t()),
          type: String.t() | nil,
          data: map(),
          read_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  schema "user_notifications" do
    field :type, :string
    field :data, :map, default: %{}
    field :read_at, :utc_datetime

    belongs_to :user, User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "Changeset for creating a notification."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :type, :data, :read_at])
    |> validate_required([:user_id, :type, :data])
    |> foreign_key_constraint(:user_id)
  end

  @doc "Changeset for marking a notification as read."
  @spec read_changeset(t(), DateTime.t()) :: Ecto.Changeset.t()
  def read_changeset(notification, read_at) do
    change(notification, read_at: read_at)
  end

  @doc "Inserts a new notification for the given user."
  @spec insert(User.t(), String.t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def insert(user, type, data) do
    # AIDEV-NOTE: stringify keys so data always has string keys, matching DB reload behaviour
    string_data = Map.new(data, fn {k, v} -> {to_string(k), v} end)

    %__MODULE__{}
    |> changeset(%{user_id: user.id, type: type, data: string_data})
    |> Repo.insert()
  end

  @doc "Marks a notification as read."
  @spec mark_read(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def mark_read(notification) do
    notification
    |> read_changeset(DateTime.utc_now(:second))
    |> Repo.update()
  end

  @doc "Marks all unread notifications for a user as read."
  @spec mark_all_read(User.t()) :: :ok
  def mark_all_read(user) do
    __MODULE__
    |> where([n], n.user_id == ^user.id and is_nil(n.read_at))
    |> Repo.update_all(set: [read_at: DateTime.utc_now(:second)])

    :ok
  end

  @doc "Lists unread notifications for a user, most recent first."
  @spec list_unread(User.t()) :: [t()]
  def list_unread(user) do
    __MODULE__
    |> where([n], n.user_id == ^user.id and is_nil(n.read_at))
    |> order_by([n], desc: n.id)
    |> Repo.all()
  end

  @doc "Unread notification count for a user."
  @spec unread_count(User.t()) :: non_neg_integer()
  def unread_count(user) do
    __MODULE__
    |> where([n], n.user_id == ^user.id and is_nil(n.read_at))
    |> Repo.aggregate(:count, :id)
  end

  @doc "Deletes all read notifications inserted before the given cutoff datetime. Returns the deleted count."
  @spec delete_read_before(DateTime.t()) :: non_neg_integer()
  def delete_read_before(cutoff) do
    {deleted, _} =
      __MODULE__
      |> where([n], not is_nil(n.read_at) and n.inserted_at < ^cutoff)
      |> Repo.delete_all()

    deleted
  end
end
