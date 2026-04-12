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
  defdelegate get_tracks(user_id, date), to: RadioTrack, as: :for_date
  defdelegate delete_tracks_before(user_id, cutoff_datetime), to: RadioTrack, as: :delete_before

  # Services
  def start_radio(user), do: TrackSpotifyPlayback.in_seconds(%{user_id: user.id}, 15)
  def stop_radio(user), do: TrackSpotifyPlayback.cancel_all(user.id)
  defdelegate insert_track(user_id, provider, track_data), to: Backfill
  defdelegate backward_fill(provider), to: Backfill

  # Workers
  defdelegate next_in?(user_id), to: TrackSpotifyPlayback
end
