defmodule PremiereEcoute.Accounts.Services.AccountFollow do
  @moduledoc """
  Account follow service.

  Manages user follows for streamers by fetching follow status from Twitch API and creating follow records with background worker support for bulk operations.
  """

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Follow
  alias PremiereEcoute.Apis

  defmodule Worker do
    @moduledoc """
    Oban worker for processing follow operations.

    Fetches follow status from Twitch API and creates follow records asynchronously.
    """

    use PremiereEcouteCore.Worker, queue: :twitch

    require Logger

    alias PremiereEcoute.Accounts
    alias PremiereEcoute.Accounts.Scope
    alias PremiereEcoute.Apis

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"streamer_id" => streamer_id, "user_id" => user_id}}) do
      with scope <- Scope.for_user(Accounts.get_user!(user_id)),
           streamer <- Accounts.get_user!(streamer_id),
           {:ok, %{"followed_at" => at}} <- Apis.twitch().get_followed_channel(scope, streamer) do
        Accounts.follow(scope.user, streamer, %{followed_at: NaiveDateTime.from_iso8601!(at)})
      else
        _ -> {:error, :no_follow}
      end
    end
  end

  @spec follow_streamer(Scope.t(), User.t()) :: {:ok, Follow.t()} | {:error, term()}
  def follow_streamer(scope, streamer) do
    with {:ok, %{"followed_at" => followed_at}} <- Apis.twitch().get_followed_channel(scope, streamer),
         followed_at <- NaiveDateTime.from_iso8601!(followed_at),
         {:ok, follow} <- Accounts.follow(scope.user, streamer, %{followed_at: followed_at}) do
      {:ok, follow}
    else
      _ -> Accounts.follow(scope.user, streamer, %{followed_at: nil})
    end
  end

  @spec follow_streamers(Scope.t()) :: :ok
  def follow_streamers(scope) do
    User.all(where: [role: :streamer])
    |> Enum.map(fn streamer -> %{streamer_id: streamer.id, user_id: scope.user.id} end)
    |> __MODULE__.Worker.in_seconds(10)

    :ok
  end
end
