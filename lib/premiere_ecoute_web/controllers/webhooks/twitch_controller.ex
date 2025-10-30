defmodule PremiereEcouteWeb.Webhooks.TwitchController do
  use PremiereEcouteWeb, :controller

  require Logger

  alias PremiereEcoute.Events.Chat.MessageSent
  alias PremiereEcoute.Events.Chat.PollEnded
  alias PremiereEcoute.Events.Chat.PollStarted
  alias PremiereEcoute.Events.Chat.PollUpdated
  alias PremiereEcoute.Sessions
  alias PremiereEcoute.Telemetry.ApiMetrics
  alias PremiereEcouteWeb.Plugs.TwitchHmacValidator

  def handle(conn, _params) do
    conn
    |> put_resp_content_type("text/plain")
    |> then(fn conn ->
      twitch_hmac = Map.get(conn.assigns, :twitch_hmac, false)
      type = TwitchHmacValidator.at(conn.req_headers, "type")
      ApiMetrics.webhook_event(:twitch, type)
      {twitch_hmac, type, conn}
    end)
    |> case do
      {false, _, conn} ->
        send_resp(conn, 401, "")

      {true, "webhook_callback_verification", conn} ->
        send_resp(conn, 200, conn.body_params["challenge"])

      {true, "revocation", conn} ->
        Logger.error("revocation: #{inspect(conn.body_params)}")
        send_resp(conn, 204, "")

      {true, "notification", conn} ->
        case handle(conn.body_params) do
          %MessageSent{} = event -> Sessions.publish_message(event)
          event -> Sessions.publish_poll(event)
        end

        send_resp(conn, 202, "")
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
    %MessageSent{
      broadcaster_id: broadcaster_id,
      user_id: user_id,
      message: text,
      is_streamer: false
    }
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

  # AIDEV-NOTE: Stream status handlers - logs stream start/stop events for monitoring
  def handle(%{
        "subscription" => %{"type" => "stream.online"},
        "event" =>
          %{
            "broadcaster_user_id" => broadcaster_id,
            "broadcaster_user_name" => broadcaster_name
          } = event
      }) do
    Logger.info(
      "Stream started: #{broadcaster_name} (ID: #{broadcaster_id}) - #{inspect(Map.take(event, ["type", "started_at"]))}"
    )

    nil
  end

  def handle(%{
        "subscription" => %{"type" => "stream.offline"},
        "event" => %{
          "broadcaster_user_id" => broadcaster_id,
          "broadcaster_user_name" => broadcaster_name
        }
      }) do
    Logger.info("Stream ended: #{broadcaster_name} (ID: #{broadcaster_id})")
    nil
  end

  def handle(_), do: nil
end
