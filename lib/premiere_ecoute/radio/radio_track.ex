defmodule PremiereEcoute.Radio.RadioTrack do
  @moduledoc """
  Schema for tracks played during a Twitch stream.
  """

  use PremiereEcouteCore.Aggregate

  alias PremiereEcoute.Accounts.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          provider_id: String.t() | nil,
          name: String.t() | nil,
          artist: String.t() | nil,
          album: String.t() | nil,
          duration_ms: integer() | nil,
          started_at: DateTime.t() | nil
        }

  schema "radio_tracks" do
    belongs_to :user, User

    field :provider_id, :string
    field :name, :string
    field :artist, :string
    field :album, :string
    field :duration_ms, :integer
    field :started_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(radio_track, attrs) do
    radio_track
    |> cast(attrs, [:user_id, :provider_id, :name, :artist, :album, :duration_ms, :started_at])
    |> validate_required([:user_id, :provider_id, :name, :artist, :started_at])
  end

  @doc """
  Insert a new track for a user.
  Prevents consecutive duplicates (same provider_id as last track for that user).

  ## Examples

      iex> insert(user_id, %{provider_id: "spotify:track:123", ...})
      {:ok, %RadioTrack{}}

      iex> insert(user_id, %{provider_id: "same_as_last", ...})
      {:error, :consecutive_duplicate}

  """
  @spec insert(integer(), map()) ::
          {:ok, t()} | {:error, :consecutive_duplicate | Ecto.Changeset.t()}
  def insert(user_id, track_data) do
    case last_for_user(user_id) do
      %__MODULE__{provider_id: same} when same == track_data.provider_id ->
        {:error, :consecutive_duplicate}

      _ ->
        %__MODULE__{}
        |> changeset(Map.put(track_data, :user_id, user_id))
        |> Repo.insert()
    end
  end

  @doc """
  Get the most recently started track for a user.

  ## Examples

      iex> last_for_user(user_id)
      %RadioTrack{}

      iex> last_for_user(user_id_with_no_tracks)
      nil

  """
  @spec last_for_user(integer()) :: t() | nil
  def last_for_user(user_id) do
    from(t in __MODULE__,
      where: t.user_id == ^user_id,
      order_by: [desc: t.started_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Get all tracks for a user on a specific date, ordered chronologically.

  ## Examples

      iex> for_date(user_id, ~D[2026-02-17])
      [%RadioTrack{}, ...]

  """
  @spec for_date(integer(), Date.t()) :: [t()]
  def for_date(user_id, date) do
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    from(t in __MODULE__,
      where: t.user_id == ^user_id and t.started_at >= ^start_of_day and t.started_at <= ^end_of_day,
      order_by: [asc: t.started_at]
    )
    |> Repo.all()
  end

  @doc """
  Delete all tracks for a user that started before the given datetime.

  ## Examples

      iex> delete_before(user_id, cutoff_datetime)
      {2, nil}

  """
  @spec delete_before(integer(), DateTime.t()) :: {integer(), nil | [term()]}
  def delete_before(user_id, cutoff_datetime) do
    from(t in __MODULE__,
      where: t.user_id == ^user_id and t.started_at < ^cutoff_datetime
    )
    |> Repo.delete_all()
  end
end
