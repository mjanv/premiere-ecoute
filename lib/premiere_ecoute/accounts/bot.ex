defmodule PremiereEcoute.Accounts.Bot do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Core.Cache

  @bot "premiereecoutebot@twitch.tv"

  def get do
    case Cache.get(:users, :bot) do
      {:ok, nil} ->
        case Accounts.get_user_by_email(@bot) do
          nil ->
            nil

          %Accounts.User{} = user ->
            case renew_twitch_token(user) do
              {:ok, user} ->
                Cache.put(:users, :bot, user, expire: 5 * 60 * 1_000)
                user

              {:error, user} ->
                user
            end
        end

      {:ok, user} ->
        user

      _ ->
        nil
    end
  end

  def renew_twitch_token(user) do
    with {:ok, tokens} <- Apis.twitch().renew_token(user.twitch_refresh_token),
         {:ok, user} <- User.update_twitch_tokens(user, tokens) do
      {:ok, user}
    else
      {:error, reason} ->
        Logger.error("Failed to renew Bot twitch tokens: #{inspect(reason)}")
        {:error, user}
    end
  end
end
