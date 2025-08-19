defmodule PremiereEcoute.Billboards.Billboard do
  @moduledoc """
  Billboard schema for storing music billboards created by streamers.

  A billboard represents a curated collection of playlist submissions from a streamer,
  used to generate ranked music charts based on track frequency across multiple playlists.
  """

  use PremiereEcouteCore.Aggregate,
    root: [:streamer],
    json: [:id, :billboard_id, :title, :submissions, :status, :user_id]

  alias PremiereEcoute.Accounts.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          billboard_id: String.t() | nil,
          title: String.t() | nil,
          submissions: [%{url: String.t()}] | nil,
          status: :created | :active | :stopped,
          user_id: integer() | nil,
          streamer: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "billboards" do
    field :billboard_id, :string
    field :title, :string
    field :submissions, {:array, :map}
    field :status, Ecto.Enum, values: [:created, :active, :stopped], default: :created

    belongs_to :streamer, User, foreign_key: :user_id

    timestamps(type: :utc_datetime)
  end

  def changeset(billboard, attrs) do
    billboard
    |> cast(attrs, [:billboard_id, :title, :submissions, :status, :user_id])
    |> validate_required([:billboard_id, :title, :user_id])
    |> validate_length(:title, min: 1, max: 512)
    |> validate_length(:billboard_id, min: 1, max: 255)
    |> validate_inclusion(:status, [:created, :active, :stopped])
    |> unique_constraint(:billboard_id)
    |> foreign_key_constraint(:user_id)
  end

  def create(%__MODULE__{} = billboard) do
    billboard
    |> Map.from_struct()
    |> Map.put(:billboard_id, String.downcase(Base.encode16(:crypto.strong_rand_bytes(4))))
    |> then(fn attrs -> Repo.insert(changeset(%__MODULE__{}, attrs)) end)
  end
end
