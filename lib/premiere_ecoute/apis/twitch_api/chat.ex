defmodule PremiereEcoute.Apis.TwitchApi.Chat do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts.Bot
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.TwitchApi

  def send_chat_message(%Scope{user: %{twitch: %{user_id: user_id}}}, message) do
    bot = Bot.get()

    bot.twitch.access_token
    |> TwitchApi.api()
    |> TwitchApi.post(
      url: "/chat/messages",
      json: %{
        broadcaster_id: user_id,
        sender_id: bot.twitch.user_id,
        message: message
      }
    )
    |> TwitchApi.handle(200, fn
      %{"data" => [%{"is_sent" => false, "drop_reason" => reason}]} ->
        Logger.error("Cannot sent message to chat user_id due to #{inspect(reason)}")

      %{"data" => [message]} ->
        message
    end)
  end

  def send_chat_announcement(%Scope{user: %{twitch: %{user_id: user_id}}}, message, color \\ "purple") do
    bot = Bot.get()

    bot.twitch.access_token
    |> TwitchApi.api()
    |> TwitchApi.post(
      url: "/chat/announcements",
      params: %{broadcaster_id: user_id, moderator_id: bot.twitch.user_id},
      json: %{message: message, color: color}
    )
    |> TwitchApi.handle(204, fn _ -> message end)
  end
end
