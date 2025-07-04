defmodule PremiereEcouteWeb.Webhooks.TwitchController do
  use PremiereEcouteWeb, :controller

  require Logger

  alias PremiereEcoute.Apis.Events.MessageSent
  alias PremiereEcoute.Apis.Events.PollEnded
  alias PremiereEcoute.Apis.Events.PollStarted
  alias PremiereEcoute.Apis.Events.PollUpdated
  alias PremiereEcoute.Core

  def handle_event(conn, _params) do
    headers = Enum.into(conn.req_headers, %{})

    case headers["twitch-eventsub-message-type"] do
      "webhook_callback_verification" ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, conn.body_params["challenge"])

      "revocation" ->
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
        "event" => %{"chatter_user_id" => user_id, "message" => %{"text" => text}}
      }) do
    %MessageSent{user_id: user_id, message: text}
  end

  def handle(%{
        "subscription" => %{"type" => "channel.poll.begin"},
        "event" => %{"id" => id}
      }) do
    %PollStarted{id: id}
  end

  def handle(%{
        "subscription" => %{"type" => "channel.poll.progress"},
        "event" => %{"id" => id}
      }) do
    %PollUpdated{id: id}
  end

  def handle(%{
        "subscription" => %{"type" => "channel.poll.end"},
        "event" => %{"id" => id}
      }) do
    %PollEnded{id: id}
  end

  def handle(_), do: nil
end
