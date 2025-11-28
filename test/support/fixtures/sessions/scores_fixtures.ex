defmodule PremiereEcoute.Sessions.ScoresFixtures do
  @moduledoc """
  Scores fixtures.

  Provides factory functions to generate test vote data for listening sessions.
  """

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Scores.Vote

  @doc """
  Creates vote for user on current listening session track.

  Generates vote with random value from session vote options, marks streamer status based on user role, and persists via Vote.create/1.
  """
  @spec vote(map(), map()) :: {:ok, Vote.t()} | {:error, Ecto.Changeset.t()}
  def vote(%{twitch: %{user_id: viewer_id}, role: role}, %{id: session_id, current_track: %{id: track_id}, vote_options: options}) do
    %Vote{
      viewer_id: viewer_id,
      session_id: session_id,
      track_id: track_id,
      value: Enum.random(options),
      is_streamer: role == :streamer
    }
    |> Vote.create()
  end

  @doc """
  Creates vote fixture in database with custom attributes.

  Inserts vote record with provided attributes merged with is_streamer default false, returning persisted vote struct for testing.
  """
  @spec vote_fixture(map()) :: Vote.t()
  def vote_fixture(attrs \\ %{}) do
    {:ok, vote} =
      %Vote{}
      |> Vote.changeset(attrs |> Map.put_new(:is_streamer, false))
      |> Repo.insert()

    vote
  end
end
