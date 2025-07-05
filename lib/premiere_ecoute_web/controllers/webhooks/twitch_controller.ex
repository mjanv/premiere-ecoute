defmodule PremiereEcouteWeb.Webhooks.TwitchController do
  use PremiereEcouteWeb, :controller

  require Logger

  alias PremiereEcoute.Core
  alias PremiereEcoute.Sessions.Scores.Events.MessageSent
  alias PremiereEcoute.Sessions.Scores.Events.PollEnded
  alias PremiereEcoute.Sessions.Scores.Events.PollStarted
  alias PremiereEcoute.Sessions.Scores.Events.PollUpdated

  def handle_event(conn, _params) do
    headers = Enum.into(conn.req_headers, %{})

    case headers["twitch-eventsub-message-type"] do
      "webhook_callback_verification" ->
        Logger.info("Webhook callback verification: #{inspect(conn.body_params)}")

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, conn.body_params["challenge"])

      "revocation" ->
        Logger.error("Revocation: #{inspect(conn.body_params)}")

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(204, "")

      "notification" ->
        Core.dispatch(handle(conn.body_params))

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(202, "")
    end
  end

  def handle(%{
        "subscription" => %{"type" => "channel.chat.message"},
        "event" => %{
          "broadcaster_user_id" => broadcaster_id,
          "chatter_user_id" => user_id,
          "message" => %{"text" => text}
        }
      }) do
    %MessageSent{broadcaster_id: broadcaster_id, user_id: user_id, message: text}
  end

  def handle(%{
        "subscription" => %{"type" => "channel.poll.begin"},
        "event" => %{"id" => id, "title" => title, "choices" => choices}
      }) do
    votes =
      choices
      |> Enum.map(fn %{"title" => title} -> {title, 0} end)
      |> Enum.into(%{})

    %PollStarted{id: id, title: title, votes: votes}
  end

  def handle(%{
        "subscription" => %{"type" => "channel.poll.progress"},
        "event" => %{"id" => id, "choices" => choices}
      }) do
    votes =
      choices
      |> Enum.map(fn %{"title" => title, "votes" => votes} -> {title, votes} end)
      |> Enum.into(%{})

    %PollUpdated{id: id, votes: votes}
  end

  def handle(%{
        "subscription" => %{"type" => "channel.poll.end"},
        "event" => %{"id" => id, "choices" => choices}
      }) do
    votes =
      choices
      |> Enum.map(fn %{"title" => title, "votes" => votes} -> {title, votes} end)
      |> Enum.into(%{})

    %PollEnded{id: id, votes: votes}
  end

  def handle(_), do: nil
end
