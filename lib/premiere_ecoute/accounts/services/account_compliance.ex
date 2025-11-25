defmodule PremiereEcoute.Accounts.Services.AccountCompliance do
  @moduledoc """
  Account compliance service.

  Handles GDPR compliance including exporting user data with anonymization, deleting accounts with cascading cleanup of tokens/follows/votes/sessions, and publishing compliance events.
  """

  import Ecto.Query

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Follow
  alias PremiereEcoute.Accounts.User.Token
  alias PremiereEcoute.Events.AccountDeleted
  alias PremiereEcoute.Events.PersonalDataRequested
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Repo
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Sessions.ListeningSession
  alias PremiereEcoute.Sessions.Scores.Vote

  @spec download_associated_data(Scope.t()) :: {:ok, binary()} | {:error, term()}
  def download_associated_data(scope) do
    try do
      user = User.preload(scope.user)
      votes = Sessions.viewer_votes(user)
      events = Store.read("user-#{scope.user.id}", :raw)

      %{
        metadata: %{
          generated_at: DateTime.utc_now(),
          host: System.get_env("PHX_HOST", "localhost"),
          version: to_string(Application.spec(:premiere_ecoute)[:vsn])
        },
        data: %{profile: scope.user, activity: %{follows: user.channels, votes: votes}},
        events: events
      }
      |> Jason.encode!()
      |> Jason.decode!()
      |> anonym(["data", "activity", "follows"], ["id"])
      |> anonym(["data", "activity", "votes"], ["session_id", "track_id", "value", "inserted_at"])
      |> Jason.encode!()
      |> then(fn data -> {:ok, data} end)
    rescue
      error ->
        Logger.error("#{inspect(error)}")
        {:error, "Cannot generate associated data"}
    end
    |> Store.any("user", fn {result, _} -> %PersonalDataRequested{id: scope.user.id, result: result} end)
  end

  defp anonym(data, path, keys) do
    update_in(data, path, fn channels -> channels |> Enum.map(&Map.take(&1, keys)) end)
  end

  @spec delete_account(Scope.t()) :: {:ok, User.t()} | {:error, term()}
  def delete_account(scope) do
    user = scope.user

    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:tokens, Token.by_user_and_contexts_query(user, :all))
    |> Ecto.Multi.delete_all(:viewer_follows, from(f in Follow, where: f.user_id == ^user.id))
    |> Ecto.Multi.delete_all(:streamer_follows, from(f in Follow, where: f.streamer_id == ^user.id))
    |> Ecto.Multi.delete_all(:votes, from(v in Vote, where: v.viewer_id == ^user.twitch.user_id))
    |> Ecto.Multi.delete_all(:sessions, from(s in ListeningSession, where: s.user_id == ^user.id))
    |> Ecto.Multi.delete(:user, user)
    |> Ecto.Multi.run(:event, fn _, _ ->
      :ok = Store.append(%AccountDeleted{id: user.id}, stream: "user")
      {:ok, nil}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: deleted_user}} -> {:ok, deleted_user}
      {:error, _step, changeset, _changes} -> {:error, changeset}
    end
  end
end
