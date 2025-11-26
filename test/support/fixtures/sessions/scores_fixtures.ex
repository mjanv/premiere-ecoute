defmodule PremiereEcoute.Sessions.ScoresFixtures do
  @moduledoc """
  Scores fixtures.

  Provides factory functions to generate test vote data for listening sessions.
  """

  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions.Scores.Vote

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

  def vote_fixture(attrs \\ %{}) do
    {:ok, vote} =
      %Vote{}
      |> Vote.changeset(attrs |> Map.put_new(:is_streamer, false))
      |> Repo.insert()

    vote
  end
end
