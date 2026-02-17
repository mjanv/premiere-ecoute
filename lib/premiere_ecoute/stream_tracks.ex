defmodule PremiereEcoute.StreamTracks do
  @moduledoc """
  Context for managing stream playback tracking.
  Completely decoupled from discography - only related to users.
  """

  # AIDEV-NOTE: Core context for daily playlist feature - polls Spotify every 60s during streams
  # AIDEV-NOTE: Uses one-row-per-track design, no foreign keys to discography tables

  import Ecto.Query
  alias PremiereEcoute.StreamTracks.StreamTrack
  alias PremiereEcoute.Repo

  @doc """
  Insert a new track.
  Prevents consecutive duplicates (same provider_id as last track).

  ## Examples

      iex> insert_track(user_id, %{provider_id: "spotify:track:123", ...})
      {:ok, %StreamTrack{}}

      iex> insert_track(user_id, %{provider_id: "same_as_last", ...})
      {:error, :consecutive_duplicate}

  """
  @spec insert_track(integer(), map()) ::
          {:ok, StreamTrack.t()} | {:error, :consecutive_duplicate | Ecto.Changeset.t()}
  def insert_track(user_id, track_data) do
    last_track = get_last_track(user_id)
    provider_id = Map.get(track_data, :provider_id)

    case last_track do
      %StreamTrack{provider_id: ^provider_id} ->
        {:error, :consecutive_duplicate}

      _ ->
        %StreamTrack{}
        |> StreamTrack.changeset(Map.put(track_data, :user_id, user_id))
        |> Repo.insert()
    end
  end

  @doc """
  Get the last track inserted for a user.

  ## Examples

      iex> get_last_track(user_id)
      %StreamTrack{}

      iex> get_last_track(user_id_with_no_tracks)
      nil

  """
  @spec get_last_track(integer()) :: StreamTrack.t() | nil
  def get_last_track(user_id) do
    from(t in StreamTrack,
      where: t.user_id == ^user_id,
      order_by: [desc: t.started_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Get all tracks for a user on a specific date (ordered by started_at).

  ## Examples

      iex> get_tracks(user_id, ~D[2026-02-17])
      [%StreamTrack{}, ...]

  """
  @spec get_tracks(integer(), Date.t()) :: [StreamTrack.t()]
  def get_tracks(user_id, date) do
    start_of_day = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_of_day = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")

    from(t in StreamTrack,
      where: t.user_id == ^user_id and t.started_at >= ^start_of_day and t.started_at <= ^end_of_day,
      order_by: [asc: t.started_at]
    )
    |> Repo.all()
  end

  @doc """
  Delete tracks older than cutoff datetime.

  ## Examples

      iex> delete_tracks_before(user_id, cutoff_datetime)
      {2, nil}

  """
  @spec delete_tracks_before(integer(), DateTime.t()) :: {integer(), nil | [term()]}
  def delete_tracks_before(user_id, cutoff_datetime) do
    from(t in StreamTrack,
      where: t.user_id == ^user_id and t.started_at < ^cutoff_datetime
    )
    |> Repo.delete_all()
  end
end
