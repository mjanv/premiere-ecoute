defmodule PremiereEcoute.Radio do
  @moduledoc """
  Context for managing stream playback tracking.
  """

  alias PremiereEcoute.Radio.RadioTrack
  alias PremiereEcoute.Radio.Workers.LinkProviderTrack

  @doc """
  Insert a new track for a user and schedule provider ID resolution 15 seconds later.
  """
  @spec insert_track(integer(), String.t(), map()) ::
          {:ok, RadioTrack.t()} | {:error, :consecutive_duplicate | Ecto.Changeset.t()}
  def insert_track(user_id, provider, track_data) do
    with {:ok, track} <- RadioTrack.insert(user_id, track_data),
         {:ok, _job} <- LinkProviderTrack.in_seconds(%{radio_track_id: track.id, provider: provider}, 15) do
      {:ok, track}
    end
  end

  @doc """
  Fill all missing providers in radio tracks already registered
  """
  @spec backward_fill(atom()) :: :ok
  def backward_fill(provider) do
    RadioTrack.all()
    |> Enum.with_index(fn track, seconds -> {track, seconds} end)
    |> Enum.each(fn {track, seconds} ->
      LinkProviderTrack.in_seconds(%{radio_track_id: track.id, provider: provider}, seconds)
    end)
  end

  defdelegate get_track(track_id), to: RadioTrack, as: :get
  defdelegate add_provider(track, new_ids), to: RadioTrack, as: :update_provider_ids
  defdelegate get_tracks(user_id, date), to: RadioTrack, as: :for_date
  defdelegate delete_tracks_before(user_id, cutoff_datetime), to: RadioTrack, as: :delete_before
end
