defmodule PremiereEcoute.Collections.CollectionSessionWorker do
  @moduledoc """
  Oban worker for collection session background tasks.

  Handles scheduled vote window close after vote_duration expires.
  """

  use PremiereEcouteCore.Worker,
    queue: :sessions,
    max_attempts: 1,
    unique: [period: 5, keys: [:action, :session_id]]

  use Gettext, backend: PremiereEcoute.Gettext

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis
  alias PremiereEcouteCore.Cache

  # AIDEV-NOTE: Broadcasts vote counts from cache to LiveView so streamer sees final tally
  # before making the decision. Does NOT auto-decide — streamer always finalizes.
  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"action" => "close_vote", "session_id" => session_id, "user_id" => user_id, "track_id" => track_id}
      }) do
    with {:ok, cached} <- Cache.get(:collections, session_id),
         scope <- Scope.for_user(User.get(user_id)) do
      votes_a = Map.get(cached, :votes_a, 0)
      votes_b = Map.get(cached, :votes_b, 0)

      Apis.twitch().send_chat_message(
        scope,
        Gettext.with_locale(Atom.to_string(scope.user.profile.language), fn ->
          gettext("Votes are closed! Results: 1=%{a} | 2=%{b}", a: votes_a, b: votes_b)
        end)
      )

      PremiereEcoute.PubSub.broadcast("collection:#{session_id}", {:vote_closed, track_id, %{votes_a: votes_a, votes_b: votes_b}})

      # Clean up active vote state from cache but keep track list
      Cache.put(:collections, session_id, Map.drop(cached, [:active_track_id, :duel_track_id, :votes_a, :votes_b]))
    end

    :ok
  end
end
