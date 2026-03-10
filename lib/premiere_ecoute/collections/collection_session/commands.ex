defmodule PremiereEcoute.Collections.CollectionSession.Commands do
  @moduledoc "Collection session commands."

  defmodule PrepareCollectionSession do
    @moduledoc "Command - Prepare a new collection session."

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{
            scope: Scope.t(),
            origin_playlist_id: integer(),
            destination_playlist_id: integer(),
            rule: :ordered | :random,
            selection_mode: :streamer_choice | :viewer_vote | :duel,
            vote_duration: integer() | nil
          }

    defstruct [:scope, :origin_playlist_id, :destination_playlist_id, :rule, :selection_mode, :vote_duration]
  end

  defmodule StartCollectionSession do
    @moduledoc "Command - Start a collection session."

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: integer(), scope: Scope.t()}

    defstruct [:session_id, :scope]
  end

  defmodule DecideTrack do
    @moduledoc "Command - Record the streamer's decision for the current track."

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{
            session_id: integer(),
            scope: Scope.t(),
            track_id: String.t(),
            track_name: String.t(),
            artist: String.t(),
            position: integer(),
            decision: :kept | :rejected | :skipped,
            votes_a: integer(),
            votes_b: integer(),
            duel_track_id: String.t() | nil,
            duel_track_name: String.t() | nil,
            duel_artist: String.t() | nil,
            duel_position: integer() | nil
          }

    defstruct [
      :session_id,
      :scope,
      :track_id,
      :track_name,
      :artist,
      :position,
      :decision,
      :votes_a,
      :votes_b,
      :duel_track_id,
      :duel_track_name,
      :duel_artist,
      :duel_position
    ]
  end

  defmodule OpenVoteWindow do
    @moduledoc "Command - Open a vote window for the current track(s)."

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{
            session_id: integer(),
            scope: Scope.t(),
            track_id: String.t(),
            duel_track_id: String.t() | nil,
            selection_mode: (:viewer_vote | :duel | :streamer_choice) | nil,
            vote_duration: integer() | nil
          }

    defstruct [:session_id, :scope, :track_id, :duel_track_id, :selection_mode, :vote_duration]
  end

  defmodule CloseVoteWindow do
    @moduledoc "Command - Close the active vote window."

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{session_id: integer(), scope: Scope.t()}

    defstruct [:session_id, :scope]
  end

  defmodule CompleteCollectionSession do
    @moduledoc "Command - Complete the session and sync kept tracks to destination playlist."

    alias PremiereEcoute.Accounts.Scope

    @type t :: %__MODULE__{
            session_id: integer(),
            scope: Scope.t(),
            remove_kept: boolean(),
            remove_rejected: boolean()
          }

    defstruct [:session_id, :scope, remove_kept: false, remove_rejected: false]
  end
end
