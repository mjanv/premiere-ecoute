defmodule PremiereEcoute.Sessions do
  @moduledoc false

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective
  alias PremiereEcoute.Sessions.Scores.MessagePipeline
  alias PremiereEcoute.Sessions.Scores.Vote

  # Listening session
  defdelegate create_session(attrs), to: ListeningSession, as: :create
  defdelegate start_session(session), to: ListeningSession, as: :start
  defdelegate stop_session(session), to: ListeningSession, as: :stop
  defdelegate next_track(session), to: ListeningSession
  defdelegate previous_track(session), to: ListeningSession
  defdelegate active_sessions(user), to: ListeningSession
  def publish_message(message), do: PremiereEcoute.Core.publish(MessagePipeline, message)

  # Votes
  def viewer_votes(user), do: Vote.all(where: [viewer_id: user.twitch.user_id])
  defdelegate create_vote(vote), to: Vote, as: :create

  # Retrospective
  defdelegate get_albums_by_period(user_id, period, opts \\ %{}), to: Retrospective
  defdelegate get_album_session_details(session_id), to: Retrospective
end
