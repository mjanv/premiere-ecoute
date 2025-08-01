defmodule PremiereEcoute.Apis.TwitchApi.Chat do
  @moduledoc false

  alias PremiereEcoute.Accounts.Bot
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.TwitchApi

  def send_chat_message(%Scope{user: %{twitch_user_id: user_id}}, message) do
    bot = Bot.get()

    TwitchApi.api(:api, bot.twitch_access_token)
    |> TwitchApi.post(
      url: "/chat/messages",
      json: %{
        broadcaster_id: user_id,
        sender_id: bot.twitch_user_id,
        message: message
      }
    )
    |> TwitchApi.handle(200, fn %{"data" => [message]} -> message end)
  end

  def send_chat_announcement(
        %Scope{user: %{twitch_user_id: user_id, twitch_access_token: token}},
        message,
        color \\ "purple"
      ) do
    bot = Bot.get()

    TwitchApi.api(:api, token)
    |> TwitchApi.post(
      url: "/chat/announcements",
      params: %{broadcaster_id: user_id, moderator_id: bot.twitch_user_id},
      json: %{message: message, color: color}
    )
    |> TwitchApi.handle(204, fn _ -> message end)
  end
end
