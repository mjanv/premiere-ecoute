defmodule PremiereEcoute.Accounts.Bot do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.TwitchApi

  @bot "premiereecoutebot@twitch.tv"

  def get do
    case Cachex.get(:users, :bot) do
      {:ok, nil} ->
        case Accounts.get_user_by_email(@bot) do
          nil ->
            nil

          %Accounts.User{} = user ->
            renew_twitch_token(user)
            Cachex.put(:users, :bot, user, expire: 5 * 60 * 1_000)
            user
        end

      {:ok, user} ->
        user

      _ ->
        nil
    end
  end

  def renew_twitch_token(user) do
    with {:ok, tokens} <- TwitchApi.renew_token(user.twitch_refresh_token),
         {:ok, _} <- User.update_twitch_tokens(user, tokens) do
      :ok
    else
      reason ->
        Logger.error("Failed to renew Bot twitch tokens: #{inspect(reason)}")
        :error
    end
  end
end
