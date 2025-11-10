defmodule PremiereEcoute.Apis.TwitchApi.Chat do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts.Bot
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.TwitchApi

  def send_chat_messages(%Scope{} = scope, messages, interval \\ 1_000) do
    messages
    |> Enum.with_index()
    |> Enum.each(fn {message, index} ->
      send_chat_message(scope, message, index * interval)
    end)

    :ok
  end

  def send_chat_message(%Scope{} = scope, message, 0) do
    do_send_chat_message(scope, message)
    :ok
  end

  def send_chat_message(%Scope{} = scope, message, delay) do
    spawn(fn ->
      :timer.sleep(delay)
      do_send_chat_message(scope, message)
    end)

    :ok
  end

  def send_reply_message(%Scope{} = scope, message, reply_message_id) do
    do_send_chat_message(scope, message, reply_message_id)
    :ok
  end

  defp do_send_chat_message(%Scope{user: %{twitch: %{user_id: user_id}}}, message, reply_message_id \\ nil) do
    case Bot.get() do
      {:ok, bot} ->
        json1 = %{broadcaster_id: user_id, sender_id: bot.twitch.user_id, message: message}
        json2 = if is_nil(reply_message_id), do: %{}, else: %{reply_parent_message_id: reply_message_id}

        bot
        |> Scope.for_user()
        |> TwitchApi.api()
        |> TwitchApi.post(url: "/chat/messages", json: Map.merge(json1, json2))
        |> TwitchApi.handle(200, fn
          %{"data" => [%{"is_sent" => false, "drop_reason" => reason}]} ->
            Logger.error("Cannot sent message to chat #{user_id} due to #{inspect(reason)}")

          %{"data" => [message]} ->
            message
        end)

      {:error, reason} ->
        Logger.error("Cannot get bot for sending message due to #{inspect(reason)}")
        {:error, reason}
    end
  end

  def send_chat_announcement(%Scope{user: %{twitch: %{user_id: user_id}}}, message, color \\ "purple") do
    case Bot.get() do
      {:ok, bot} ->
        bot
        |> Scope.for_user()
        |> TwitchApi.api()
        |> TwitchApi.post(
          url: "/chat/announcements",
          params: %{broadcaster_id: user_id, moderator_id: bot.twitch.user_id},
          json: %{message: message, color: color}
        )
        |> TwitchApi.handle(204, fn _ -> message end)

      {:error, reason} ->
        {:error, reason}
    end

    :ok
  end
end
