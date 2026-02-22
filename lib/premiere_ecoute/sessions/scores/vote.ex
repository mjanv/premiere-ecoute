defmodule PremiereEcoute.Sessions.Scores.Vote do
  @moduledoc """
  Individual vote aggregate.

  Stores viewer votes on tracks during listening sessions, parses vote values from chat messages against configured vote options, and enforces uniqueness per viewer-session-track combination.
  """

  use PremiereEcouteCore.Aggregate,
    json: [:value, :track_id, :session_id, :viewer_id, :inserted_at]

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.ListeningSession

  @type t :: %__MODULE__{
          id: integer() | nil,
          viewer_id: String.t() | nil,
          track_id: String.t() | nil,
          value: integer() | nil,
          is_streamer: boolean(),
          session: entity(ListeningSession.t()),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "votes" do
    field :viewer_id, :string
    field :track_id, :id
    field :value, :string
    field :is_streamer, :boolean, default: false

    belongs_to :session, ListeningSession

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates changeset for vote validation.

  Validates required fields and enforces uniqueness per viewer-session-track combination.
  """
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:viewer_id, :session_id, :track_id, :is_streamer, :value])
    |> validate_required([:viewer_id, :session_id, :track_id, :is_streamer, :value])
    |> unique_constraint([:viewer_id, :session_id, :track_id], name: :vote_index)
    |> foreign_key_constraint(:session_id)
  end

  @doc """
  Parses vote value from chat message against vote options.

  Matches exact vote option or message ending with vote option pattern. Returns error if multiple vote options detected.
  """
  @spec from_message(String.t(), list(String.t())) :: {:ok, String.t()} | {:error, String.t()}
  def from_message(message, vote_options) do
    # Check if message is exactly a vote option
    if message in vote_options do
      {:ok, message}
    else
      # Check if message ends with " <vote>" pattern
      vote_options
      |> Enum.filter(fn option -> String.ends_with?(message, " #{option}") end)
      |> case do
        [vote] ->
          if Enum.any?(vote_options, fn option -> option != vote and String.contains?(message, option) end) do
            {:error, message}
          else
            {:ok, vote}
          end

        _ ->
          {:error, message}
      end
    end
  end

  @doc """
  Fetches all votes cast by a viewer for a list of track ids.

  Returns a list of maps with track_id, score, and inserted_at, ordered by track_id then most recent first.
  """
  @spec for_tracks_and_viewer(list(integer()), String.t()) :: list(map())
  def for_tracks_and_viewer(track_ids, viewer_id) do
    from(v in __MODULE__,
      where: v.track_id in ^track_ids and v.viewer_id == ^viewer_id,
      select: %{track_id: v.track_id, score: v.value, inserted_at: v.inserted_at},
      order_by: [v.track_id, desc: v.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Parses vote value from chat message using default vote options 0-10.

  Convenience function using standard vote scale.
  """
  @spec from_message(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def from_message(message) do
    from_message(message, ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"])
  end
end
