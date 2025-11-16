defmodule PremiereEcoute.Accounts.Bot do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcouteCore.Cache

  @bot Application.compile_env(:premiere_ecoute, PremiereEcoute.Accounts)[:bot]

  def get do
    with {:ok, nil} <- Cache.get(:users, :bot),
         %User{} = user <- Accounts.get_user_by_email(@bot),
         %Scope{} = scope <- Scope.for_user(user),
         %Scope{user: user} <- Accounts.maybe_renew_token(%{assigns: %{current_scope: scope}}, :twitch),
         _ <- Cache.put(:users, :bot, user, expire: 5 * 60 * 1_000) do
      {:ok, scope.user}
    else
      {:ok, %User{} = user} ->
        {:ok, user}

      reason ->
        Logger.error("Cannot read bot user due to #{inspect(reason)}")
        {:error, nil}
    end
  end
end
