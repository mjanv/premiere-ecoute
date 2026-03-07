defmodule PremiereEcoute.Radio.RadioTrack do
  @moduledoc """
  Schema for tracks played during a Twitch stream.
  """

  use PremiereEcouteCore.Aggregate

  alias PremiereEcoute.Accounts.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          artist: String.t() | nil,
          album: String.t() | nil,
          duration_ms: integer() | nil,
          started_at: DateTime.t() | nil,
          provider_ids: %{atom() => String.t()},
          user_id: integer() | nil
        }

  schema "radio_tracks" do
    field :name, :string
    field :artist, :string
    field :album, :string
    field :duration_ms, :integer
    field :started_at, :utc_datetime
    field :provider_ids, PremiereEcouteCore.Ecto.Map, default: %{}

    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(radio_track, attrs) do
    radio_track
    |> cast(attrs, [:user_id, :provider_ids, :name, :artist, :album, :duration_ms, :started_at])
    |> validate_required([:user_id, :provider_ids, :name, :artist, :started_at])
  end

  @doc """
  Insert a new track for a user.
  Prevents consecutive duplicates: a duplicate is when the last track shares at least
  one provider ID with the incoming track.

  ## Examples

      iex> insert(user_id, %{provider_ids: %{spotify: "abc123"}, ...})
      {:ok, %RadioTrack{}}

      iex> insert(user_id, %{provider_ids: %{spotify: "abc123"}, ...})
      {:error, :consecutive_duplicate}

  """
  @spec insert(integer(), map()) ::
          {:ok, t()} | {:error, :consecutive_duplicate | Ecto.Changeset.t()}
  def insert(user_id, track_data) do
    with %__MODULE__{provider_ids: provider_ids} <- last_playing(user_id),
         true <- consecutive_duplicate?(provider_ids, track_data[:provider_ids]) do
      {:error, :consecutive_duplicate}
    else
      _ ->
        %__MODULE__{}
        |> changeset(Map.put(track_data, :user_id, user_id))
        |> Repo.insert()
    end
  end

  @doc """
  Get a radio track by id.
  """
  @spec get(integer()) :: t() | nil
  def get(id), do: Repo.get(__MODULE__, id)

  @doc """
  Get the played song by user id.
  """
  @spec last_playing(integer()) :: t() | nil
  def last_playing(user_id) do
    from(t in __MODULE__,
      where: t.user_id == ^user_id,
      order_by: [desc: t.started_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Get the last played tracks for an user
  """
  @spec last_tracks(integer(), integer()) :: [t()]
  def last_tracks(user_id, limit \\ 10) do
    all(where: [user_id: user_id], order_by: [desc: :started_at], limit: limit)
  end

  @doc """
  Update the provider_ids map for a radio track.
  Merges new_ids into the existing provider_ids map.
  """
  @spec update_provider_ids(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def update_provider_ids(%__MODULE__{provider_ids: provider_ids} = track, new_ids) do
    track
    |> changeset(%{provider_ids: Map.merge(provider_ids, new_ids)})
    |> Repo.update()
  end

  @doc """
  Get all tracks for a user on a specific date, ordered chronologically.

  ## Examples

      iex> for_date(user_id, ~D[2026-02-17])
      [%RadioTrack{}, ...]

  """
  @spec for_date(integer(), Date.t()) :: [t()]
  def for_date(user_id, date) do
    start = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    stop = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    from(t in __MODULE__,
      where: t.user_id == ^user_id,
      where: t.started_at >= ^start and t.started_at <= ^stop,
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

  defp consecutive_duplicate?(a, b), do: Enum.any?(a, fn {k, v} -> Map.get(b, k) == v end)
end
