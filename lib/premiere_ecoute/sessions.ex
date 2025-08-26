defmodule PremiereEcoute.Sessions do
  @moduledoc false

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Retrospective
  alias PremiereEcoute.Sessions.Scores

  # Listening session
  defdelegate create_session(attrs), to: ListeningSession, as: :create
  defdelegate start_session(session), to: ListeningSession, as: :start
  defdelegate stop_session(session), to: ListeningSession, as: :stop
  defdelegate next_track(session), to: ListeningSession
  defdelegate previous_track(session), to: ListeningSession
  defdelegate active_sessions(user), to: ListeningSession
  def publish_message(event), do: PremiereEcouteCore.publish(Scores.MessagePipeline, event)
  def publish_poll(event), do: PremiereEcouteCore.publish(Scores.PollPipeline, event)

  # Votes
  def viewer_votes(user), do: Scores.Vote.all(where: [viewer_id: user.twitch.user_id])
  defdelegate create_vote(vote), to: Scores.Vote, as: :create

  # Retrospective
  defdelegate get_albums_by_period(user_id, period, opts \\ %{}), to: Retrospective.History
  defdelegate get_votes_by_period(user_id, period, opts \\ %{}), to: Retrospective.History
  defdelegate get_album_session_details(session_id), to: Retrospective.History
end
