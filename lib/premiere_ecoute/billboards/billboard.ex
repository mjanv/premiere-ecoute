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

  @doc "Billboard changeset."
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
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

  @doc """
  Creates a billboard with a generated billboard_id.

  Generates a random 8-character hexadecimal identifier for the billboard before insertion.
  """
  @spec create(t()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def create(%__MODULE__{} = billboard) do
    billboard
    |> Map.from_struct()
    |> Map.put(:billboard_id, String.downcase(Base.encode16(:crypto.strong_rand_bytes(4))))
    |> then(fn attrs -> Repo.insert(changeset(%__MODULE__{}, attrs)) end)
  end

  @doc """
  Finds billboards containing submissions from a specific pseudo.

  Queries billboards using JSONB array filtering and returns only the submissions matching the given pseudo. Each submission includes its index in the original array.
  """
  @spec submissions(String.t()) :: list(t())
  def submissions(pseudo) do
    query =
      from b in __MODULE__,
        where:
          fragment(
            "EXISTS (SELECT 1 FROM jsonb_array_elements(?) elem WHERE elem->>'pseudo' = ?)",
            b.submissions,
            ^pseudo
          )

    query
    |> PremiereEcoute.Repo.all()
    |> PremiereEcoute.Repo.preload([:streamer])
    |> Enum.map(fn billboard ->
      billboard.submissions
      |> Enum.with_index()
      |> Enum.map(fn {submission, i} -> Map.put(submission, "index", i) end)
      |> Enum.filter(fn submission -> submission["pseudo"] == pseudo end)
      |> then(fn submissions -> Map.put(billboard, :submissions, submissions) end)
    end)
  end
end
