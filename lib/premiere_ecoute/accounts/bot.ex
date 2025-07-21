defmodule PremiereEcoute.Accounts.Bot do
  @moduledoc false

  alias PremiereEcoute.Accounts

  @bot "premiereecoutebot@twitch.tv"

  def get do
    case :persistent_term.get(:bot, nil) do
      nil ->
        case Accounts.get_user_by_email(@bot) do
          nil -> nil
          %Accounts.User{} = user -> tap(user, fn u -> :persistent_term.put(:bot, u) end)
        end

      user ->
        user
    end
  end
end
