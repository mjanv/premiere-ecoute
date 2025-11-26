defmodule PremiereEcoute.Apis.TwitchApi.Chat do
  @moduledoc """
  Twitch chat API.

  Sends chat messages, replies, and announcements to Twitch channels via TwitchQueue for rate limiting, using bot credentials to post on behalf of users.
  """

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.TwitchApi
  alias PremiereEcoute.Apis.TwitchQueue

  def send_chat_message(%Scope{user: %User{twitch: %{user_id: user_id}}}, message) do
    TwitchQueue.push({:do_send_chat_message, %{user_id: user_id, message: message}})
    :ok
  end

  def send_reply_message(%Scope{user: %User{twitch: %{user_id: user_id}}}, message, reply_to) do
    TwitchQueue.push({:do_send_chat_message, %{user_id: user_id, message: message, reply_to: reply_to}})
    :ok
  end

  def send_chat_announcement(%Scope{user: %User{twitch: %{user_id: user_id}}}, message, color \\ "purple") do
    TwitchQueue.push({:do_send_chat_announcement, %{user_id: user_id, message: message, color: color}})
    :ok
  end

  def do_send_chat_message(%User{twitch: %{user_id: bot_id}} = bot, %{user_id: user_id, message: message} = tmp) do
    message = %{broadcaster_id: user_id, sender_id: bot_id, message: message}
    reply_to = Map.get(tmp, :reply_to)
    reply = if is_nil(reply_to), do: %{}, else: %{reply_parent_message_id: reply_to}

    bot
    |> Scope.for_user()
    |> TwitchApi.api()
    |> TwitchApi.post(url: "/chat/messages", json: Map.merge(message, reply))
    |> TwitchApi.handle(200, fn
      %{"data" => [%{"is_sent" => false, "drop_reason" => reason}]} ->
        Logger.error("Cannot sent message to chat #{user_id} due to #{inspect(reason)}")

      %{"data" => [message]} ->
        message
    end)
  end

  def do_send_chat_announcement(%User{twitch: %{user_id: bot_id}} = bot, %{user_id: user_id, message: message} = chat) do
    bot
    |> Scope.for_user()
    |> TwitchApi.api()
    |> TwitchApi.post(
      url: "/chat/announcements",
      params: %{broadcaster_id: user_id, moderator_id: bot_id},
      json: %{message: message, color: Map.get(chat, :color, "purple")}
    )
    |> TwitchApi.handle(204, fn _ -> message end)

    :ok
  end
end
