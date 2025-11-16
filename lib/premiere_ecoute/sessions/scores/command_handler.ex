defmodule PremiereEcoute.Sessions.Scores.CommandHandler do
  @moduledoc false

  use PremiereEcouteCore.CommandBus.Handler

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis
  alias PremiereEcoute.Commands.Chat.SendChatCommand

  command(PremiereEcoute.Commands.Chat.SendChatCommand)

  def handle(%SendChatCommand{command: "hello", broadcaster_id: broadcaster_id, message_id: message_id}) do
    with broadcaster when not is_nil(broadcaster) <- Accounts.get_user_by_twitch_id(broadcaster_id),
         scope <- Scope.for_user(broadcaster),
         :ok <- Apis.twitch().send_reply_message(scope, "Hello!", message_id) do
      {:ok, []}
    else
      nil ->
        Logger.error("Cannot send hello reply due to unknown broadcaster")
        {:error, []}

      {:error, reason} ->
        Logger.error("Cannot send hello reply due to: #{inspect(reason)}")
        {:error, []}
    end
  end

  def handle(_), do: {:ok, []}
end
