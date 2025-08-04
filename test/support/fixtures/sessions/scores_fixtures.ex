defmodule PremiereEcoute.Sessions.ScoresFixtures do
  @moduledoc false

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
end
