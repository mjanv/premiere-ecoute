defmodule PremiereEcoute.Sessions do
  @moduledoc """
  Sessions context.

  Manages listening session lifecycle, vote processing via Broadway pipelines, and retrospective reports with historical views of albums and votes.
  """

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
  defdelegate get_active_session(user), to: ListeningSession
  defdelegate current_session(user), to: ListeningSession
  defdelegate can_view_retrospective?(session, scope), to: ListeningSession

  @doc "Publishes chat message event to Broadway pipeline for vote processing"
  @spec publish_message(map()) :: :ok
  def publish_message(event), do: PremiereEcouteCore.publish(Scores.MessagePipeline, event)

  @doc "Publishes poll event to Broadway pipeline for vote processing"
  @spec publish_poll(map()) :: :ok
  def publish_poll(event), do: PremiereEcouteCore.publish(Scores.PollPipeline, event)

  # Votes
  @doc "Retrieves all votes cast by viewer"
  @spec viewer_votes(PremiereEcoute.Accounts.User.t()) :: list(Scores.Vote.t())
  def viewer_votes(user), do: Scores.Vote.all(where: [viewer_id: user.twitch.user_id])
  defdelegate create_vote(vote), to: Scores.Vote, as: :create
  defdelegate get_track_votes_for_user(track_ids, viewer_id), to: Scores.Vote, as: :for_tracks_and_viewer

  # Retrospective
  defdelegate get_albums_by_period(user, period, opts \\ %{}), to: Retrospective.History
  defdelegate get_votes_by_period(user, period, opts \\ %{}), to: Retrospective.History
  defdelegate get_top_tracks_by_period(user, period, opts \\ %{}), to: Retrospective.History
  defdelegate get_album_session_details(session_id), to: Retrospective.History
end
