defmodule PremiereEcoute.Radio.RadioTrack do
  @moduledoc """
  Schema for tracks played during a Twitch stream.
  """

  use PremiereEcouteCore.Aggregate

  alias PremiereEcoute.Accounts.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          provider_ids: %{atom() => String.t()},
          name: String.t() | nil,
          artist: String.t() | nil,
          album: String.t() | nil,
          duration_ms: integer() | nil,
          started_at: DateTime.t() | nil
        }

  schema "radio_tracks" do
    belongs_to :user, User

    field :provider_ids, :map, default: %{}
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
    last =
      from(t in __MODULE__, where: t.user_id == ^user_id, order_by: [desc: t.started_at], limit: 1)
      |> Repo.one()
      |> atomize_provider_ids()

    incoming_ids = track_data[:provider_ids] || track_data["provider_ids"] || %{}

    case last do
      %__MODULE__{provider_ids: last_ids} when is_map(last_ids) ->
        if consecutive_duplicate?(last_ids, incoming_ids) do
          {:error, :consecutive_duplicate}
        else
          do_insert(user_id, track_data)
        end

      _ ->
        do_insert(user_id, track_data)
    end
  end

  @doc """
  Get a radio track by id.
  """
  @spec get(integer()) :: t() | nil
  def get(id), do: Repo.get(__MODULE__, id) |> atomize_provider_ids()

  @doc """
  Update the provider_ids map for a radio track.
  Merges new_ids into the existing provider_ids map.
  """
  @spec update_provider_ids(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def update_provider_ids(%__MODULE__{provider_ids: existing} = track, new_ids) do
    merged = Map.merge(existing, atomize_keys(new_ids))

    with {:ok, updated} <- track |> changeset(%{provider_ids: merged}) |> Repo.update() do
      {:ok, atomize_provider_ids(updated)}
    end
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
    |> Enum.map(&atomize_provider_ids/1)
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

  # AIDEV-NOTE: two tracks are consecutive duplicates if they share at least one provider+id pair
  defp consecutive_duplicate?(last_ids, incoming_ids) do
    Enum.any?(incoming_ids, fn {provider, id} ->
      Map.get(last_ids, to_atom(provider)) == id
    end)
  end

  defp do_insert(user_id, track_data) do
    with {:ok, track} <-
           %__MODULE__{}
           |> changeset(Map.put(track_data, :user_id, user_id))
           |> Repo.insert() do
      {:ok, atomize_provider_ids(track)}
    end
  end

  defp atomize_provider_ids(nil), do: nil

  defp atomize_provider_ids(%__MODULE__{provider_ids: ids} = track),
    do: %{track | provider_ids: atomize_keys(ids)}

  defp atomize_keys(map), do: Map.new(map, fn {k, v} -> {to_atom(k), v} end)

  defp to_atom(k) when is_atom(k), do: k
  defp to_atom(k) when is_binary(k), do: String.to_existing_atom(k)
end
