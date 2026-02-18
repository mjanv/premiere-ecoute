defmodule PremiereEcoute.Radio do
  @moduledoc """
  Context for managing stream playback tracking.
  """

  alias PremiereEcoute.Radio.RadioTrack

  defdelegate insert_track(user_id, track_data), to: RadioTrack, as: :insert
  defdelegate get_tracks(user_id, date), to: RadioTrack, as: :for_date
  defdelegate delete_tracks_before(user_id, cutoff_datetime), to: RadioTrack, as: :delete_before
end
