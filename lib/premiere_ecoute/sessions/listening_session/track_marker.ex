defmodule PremiereEcoute.Sessions.ListeningSession.TrackMarker do
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

  @primary_key {:id, :id, autogenerate: true}
  schema "track_markers" do
    field :track_id, :integer
    field :track_number, :integer
    field :started_at, :utc_datetime

    belongs_to :listening_session, ListeningSession
  end

  def changeset(marker, attrs) do
    marker
    |> cast(attrs, [:track_id, :track_number, :started_at, :listening_session_id])
    |> validate_required([:track_id, :track_number, :started_at, :listening_session_id])
  end

  def format_youtube_chapters(%ListeningSession{track_markers: []}, _bias), do: ""

  def format_youtube_chapters(%ListeningSession{track_markers: markers} = session, bias) do
    chapters =
      markers
      |> Enum.sort_by(& &1.started_at, {:asc, DateTime})
      |> Enum.map(fn marker ->
        track_name = get_track_name(session, marker)
        time_offset = DateTime.diff(marker.started_at, session.started_at, :second) + bias
        timestamp = format_timestamp(time_offset)

        "#{timestamp} #{track_name}"
      end)

    # Add "Introduction" chapter at 0:00 if bias > 0
    chapters = if bias > 0, do: ["0:00 Introduction" | chapters], else: chapters

    # Add "Conclusion" chapter at the end if session has ended
    chapters =
      if session.ended_at do
        session_duration = DateTime.diff(session.ended_at, session.started_at, :second)
        chapters ++ ["#{format_timestamp(session_duration + bias)} Conclusion"]
      else
        chapters
      end

    Enum.join(chapters, "\n")
  end

  defp get_track_name(%ListeningSession{source: :album, album: album}, marker) do
    Enum.find(album.tracks, %{name: ""}, &(&1.id == marker.track_id)).name
  end

  defp get_track_name(%ListeningSession{source: :playlist, playlist: playlist}, marker) do
    Enum.find(playlist.tracks, %{name: ""}, &(&1.id == marker.track_id)).name
  end

  defp format_timestamp(total_seconds) do
    hours = div(total_seconds, 3_600)
    minutes = div(rem(total_seconds, 3_600), 60)
    seconds = rem(total_seconds, 60)

    if hours > 0 do
      "#{hours}:#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(seconds), 2, "0")}"
    else
      "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
    end
  end
end
