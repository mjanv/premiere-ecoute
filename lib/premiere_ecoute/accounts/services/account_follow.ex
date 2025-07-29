defmodule PremiereEcoute.Accounts.Services.AccountFollow do
  @moduledoc false

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Follow
  alias PremiereEcoute.Apis

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
end
