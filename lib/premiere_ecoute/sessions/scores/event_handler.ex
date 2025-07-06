defmodule PremiereEcoute.Sessions.Scores.EventHandler do
  @moduledoc false

  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Events.MessageSent
  alias PremiereEcoute.Sessions.Scores.Events.PollUpdated
  alias PremiereEcoute.Sessions.Scores.Poll
  alias PremiereEcoute.Sessions.Scores.Report
  alias PremiereEcoute.Sessions.Scores.Vote

  use PremiereEcoute.Core.EventBus.Handler

  event(PremiereEcoute.Sessions.Scores.Events.MessageSent)
  event(PremiereEcoute.Sessions.Scores.Events.PollUpdated)

  def dispatch(%MessageSent{
        broadcaster_id: broadcaster_id,
        user_id: user_id,
        message: message,
        is_streamer: is_streamer
      }) do
    with {:ok, value} <- Vote.from_message(message),
         {:ok, {session_id, track_id}} <- Cachex.get(:sessions, broadcaster_id),
         vote <- %Vote{
           viewer_id: user_id,
           session_id: session_id,
           track_id: track_id,
           value: value,
           is_streamer: is_streamer
         },
         {:ok, vote} <- Vote.create(vote),
         {:ok, _} <- Report.generate(%ListeningSession{id: session_id}),
         :ok <-
           PremiereEcouteWeb.PubSub.broadcast("session:#{session_id}", vote) do
      :ok
    else
      _ -> :ok
    end
  end

  def dispatch(%PollUpdated{id: id, votes: votes}) do
    with total_votes <- Enum.sum(Map.values(votes)),
         {:ok, _} <- Poll.upsert(%Poll{poll_id: id, total_votes: total_votes, votes: votes}) do
      :ok
    else
      _ -> :ok
    end
  end

  def dispatch(_), do: :ok
end
