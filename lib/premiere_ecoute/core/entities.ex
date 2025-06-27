defmodule PremiereEcoute.Core.Entities do
  @moduledoc """
  Core domain entities for the Premiere Ecoute system.
  All entities are pure Elixir structs without external dependencies.
  """

  defmodule Album do
    @moduledoc "An album with metadata and tracks"
    defstruct [
      :id,
      :spotify_id,
      :name,
      :artist,
      :release_date,
      :cover_url,
      :total_tracks,
      :tracks,
      :inserted_at,
      :updated_at
    ]

    @type t :: %__MODULE__{
            id: String.t() | nil,
            spotify_id: String.t(),
            name: String.t(),
            artist: String.t(),
            release_date: Date.t() | nil,
            cover_url: String.t() | nil,
            total_tracks: integer(),
            tracks: [Track.t()],
            inserted_at: DateTime.t() | nil,
            updated_at: DateTime.t() | nil
          }
  end

  defmodule Track do
    @moduledoc "A track within an album"
    defstruct [
      :id,
      :spotify_id,
      :album_id,
      :name,
      :track_number,
      :duration_ms,
      :preview_url,
      :inserted_at,
      :updated_at
    ]

    @type t :: %__MODULE__{
            id: String.t() | nil,
            spotify_id: String.t(),
            album_id: String.t(),
            name: String.t(),
            track_number: integer(),
            duration_ms: integer(),
            preview_url: String.t() | nil,
            inserted_at: DateTime.t() | nil,
            updated_at: DateTime.t() | nil
          }
  end

  defmodule ListeningSession do
    @moduledoc "A listening session where streamers and viewers rate an album"
    defstruct [
      :id,
      :streamer_id,
      :album_id,
      :current_track_id,
      :status,
      :started_at,
      :ended_at,
      :inserted_at,
      :updated_at
    ]

    @type status :: :preparing | :active | :stopped
    @type t :: %__MODULE__{
            id: String.t() | nil,
            streamer_id: String.t(),
            album_id: String.t(),
            current_track_id: String.t() | nil,
            status: status(),
            started_at: DateTime.t() | nil,
            ended_at: DateTime.t() | nil,
            inserted_at: DateTime.t() | nil,
            updated_at: DateTime.t() | nil
          }
  end

  defmodule Vote do
    @moduledoc "A vote cast for a track during a session"
    defstruct [
      :id,
      :session_id,
      :track_id,
      :voter_id,
      :voter_type,
      :vote_value,
      :inserted_at
    ]

    @type voter_type :: :streamer | :viewer
    @type t :: %__MODULE__{
            id: String.t() | nil,
            session_id: String.t(),
            track_id: String.t(),
            voter_id: String.t(),
            voter_type: voter_type(),
            vote_value: 1..10,
            inserted_at: DateTime.t() | nil
          }
  end

  defmodule GradeReport do
    @moduledoc "Final grade report for a completed session"
    defstruct [
      :id,
      :session_id,
      :album_id,
      :streamer_score,
      :viewer_score,
      :track_scores,
      :total_votes,
      :generated_at
    ]

    @type track_score :: %{
            track_id: String.t(),
            track_name: String.t(),
            track_number: integer(),
            streamer_score: float() | nil,
            viewer_score: float(),
            vote_count: integer()
          }

    @type t :: %__MODULE__{
            id: String.t() | nil,
            session_id: String.t(),
            album_id: String.t(),
            streamer_score: float() | nil,
            viewer_score: float(),
            track_scores: [track_score()],
            total_votes: integer(),
            generated_at: DateTime.t() | nil
          }
  end
end
