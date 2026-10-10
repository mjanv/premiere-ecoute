defmodule PremiereEcoute.Radio do
  @moduledoc """
  Context for managing stream playback tracking.
  """

  use PremiereEcouteCore.Context

  alias PremiereEcoute.Radio.RadioTrack
  alias PremiereEcoute.Radio.Services.Backfill
  alias PremiereEcoute.Radio.Workers.TrackSpotifyPlayback

  # Model
  defdelegate get_track(track_id), to: RadioTrack, as: :get
  defdelegate last_tracks(user_id, limit \\ 10), to: RadioTrack, as: :last_tracks
  defdelegate add_provider(track, new_ids), to: RadioTrack, as: :update_provider_ids

  @doc """
  Lists the tracks played on a given day.
  """
  @spec get_tracks(integer(), Date.t(), keyword()) :: [RadioTrack.t()]
  def get_tracks(user_id, date, filters \\ []), do: RadioTrack.for_date(user_id, date, filters)

  @doc """
  Lists the tracks played between two days, both included.
  """
  @spec get_tracks_range(integer(), Date.t(), Date.t(), keyword()) :: [RadioTrack.t()]
  def get_tracks_range(user_id, date_from, date_to, filters \\ []), do: RadioTrack.for_range(user_id, date_from, date_to, filters)
  defdelegate delete_tracks_before(user_id, cutoff_datetime), to: RadioTrack, as: :delete_before

  # Services
  @doc """
  Schedules the tracking of the user's Spotify playback.
  """
  @spec start_radio(PremiereEcoute.Accounts.User.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def start_radio(user), do: TrackSpotifyPlayback.in_seconds(%{user_id: user.id}, 15)

  @doc """
  Cancels the scheduled tracking of the user's Spotify playback.
  """
  @spec stop_radio(PremiereEcoute.Accounts.User.t()) :: {:ok, non_neg_integer()}
  def stop_radio(user), do: TrackSpotifyPlayback.cancel_all(user_id: user.id)
  defdelegate insert_track(user_id, provider, track_data), to: Backfill
  defdelegate backward_fill(provider), to: Backfill

  # Workers
  @doc """
  Returns when the next playback tracking is scheduled, or `nil`.
  """
  @spec next_in?(integer()) :: DateTime.t() | nil
  def next_in?(user_id), do: TrackSpotifyPlayback.next_in?(user_id: user_id)
end
