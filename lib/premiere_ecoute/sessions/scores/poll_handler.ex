defmodule PremiereEcoute.Sessions.Scores.PollHandler do
  @moduledoc false

  use PremiereEcoute.Core.EventBus.Handler

  event(PremiereEcoute.Sessions.Scores.Events.PollUpdated)

  alias PremiereEcoute.Sessions.Scores.Events.PollUpdated
  alias PremiereEcoute.Sessions.Scores.Poll

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
