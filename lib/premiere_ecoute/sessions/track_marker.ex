defmodule PremiereEcoute.Sessions.TrackMarker do
  @moduledoc """
  Schema for tracking when tracks start playing during a listening session.

  Records a time marker each time a track begins playback, enabling:
  - Chronological history of tracks played during a session
  - Calculation of actual listening duration per track
  - Support for repeated plays (e.g., skipping back to previous tracks)
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias PremiereEcoute.Sessions.ListeningSession

  # AIDEV-NOTE: No timestamps() - only track business-relevant started_at
  @primary_key {:id, :id, autogenerate: true}
  schema "track_markers" do
    field :track_id, :integer
    field :track_number, :integer
    field :started_at, :utc_datetime

    belongs_to :listening_session, ListeningSession
  end

  @doc """
  Changeset for creating a track marker.

  ## Required fields
  - `track_id`: Database ID of the track (album_track or playlist_track)
  - `track_number`: Position in album/playlist
  - `started_at`: When the track started playing
  - `listening_session_id`: Associated session
  """
  def changeset(marker, attrs) do
    marker
    |> cast(attrs, [:track_id, :track_number, :started_at, :listening_session_id])
    |> validate_required([:track_id, :track_number, :started_at, :listening_session_id])
  end
end
