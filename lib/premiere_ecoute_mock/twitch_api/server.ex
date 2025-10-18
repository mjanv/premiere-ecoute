defmodule PremiereEcouteMock.TwitchApi.Server do
  @moduledoc false

  use Plug.Router

  require Logger

  alias PremiereEcouteMock.TwitchApi.Backend

  plug Plug.Parsers, parsers: [:json], pass: ["text/*"], json_decoder: Jason
  plug Plug.Logger
  plug :match
  plug :dispatch

  get "/:broadcaster_id/chat" do
    html_file_path = Path.join(__DIR__, "chat.html")

    case File.read(html_file_path) do
      {:ok, chat_html} ->
        updated_html =
          String.replace(
            chat_html,
            "ws://localhost:4001/chat/ws",
            "ws://localhost:4001/#{conn.params["broadcaster_id"]}/chat/ws"
          )

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, updated_html)

      {:error, _reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(500, "Chat interface file not found")
    end
  end

  get "/:broadcaster_id/chat/ws" do
    case Plug.Conn.get_req_header(conn, "upgrade") do
      ["websocket"] ->
        conn
        |> WebSockAdapter.upgrade(
          PremiereEcouteMock.TwitchApi.ChatWebSocket,
          [broadcaster_id: conn.params["broadcaster_id"]],
          timeout: 60_000
        )

      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(400, "WebSocket upgrade required")
    end
  end

  post "/chat/messages" do
    message_data = %{
      type: "message",
      username: conn.body_params["broadcaster_user_name"] || "MockUser",
      message: conn.body_params["message"] || "Test message",
      timestamp: DateTime.to_iso8601(DateTime.utc_now())
    }

    Logger.info("Broadcasting chat message: #{inspect(message_data)}")

    Registry.dispatch(PremiereEcouteMock.ChatRegistry, :chat_messages, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:chat_message, message_data})
    end)

    json(conn, 200, data(%{"message_id" => UUID.uuid4(), "is_sent" => true, "drop_reason" => nil}, %{}))
  end

  post "/chat/announcements" do
    announcement_data = %{
      type: "announcement",
      username: conn.body_params["moderator_user_name"] || "Moderator",
      message: conn.body_params["message"] || "Test announcement",
      color: conn.body_params["color"] || "purple",
      timestamp: DateTime.to_iso8601(DateTime.utc_now())
    }

    Logger.info("Broadcasting chat announcement: #{inspect(announcement_data)}")

    Registry.dispatch(PremiereEcouteMock.ChatRegistry, :chat_messages, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:chat_announcement, announcement_data})
    end)

    no_content(conn)
  end

  post "/:broadcaster_id/chat/webhook" do
    broadcaster_id = conn.params["broadcaster_id"]
    message = conn.body_params["message"]
    username = conn.body_params["broadcaster_user_name"]
    user_id = conn.body_params["broadcaster_user_id"]

    message_data = %{
      type: "message",
      username: username,
      message: message,
      timestamp: DateTime.to_iso8601(DateTime.utc_now())
    }

    Logger.info("Processing user chat message for broadcaster #{broadcaster_id}: #{inspect(message_data)}")

    Registry.dispatch(PremiereEcouteMock.ChatRegistry, :chat_messages, fn entries ->
      for {pid, _} <- entries, do: send(pid, {:chat_message, message_data})
    end)

    # Send webhook notification to main application using broadcaster_id
    send_webhook_notification("channel.chat.message", %{
      "broadcaster_user_id" => broadcaster_id,
      "broadcaster_user_login" => "premiereecoutemock",
      "broadcaster_user_name" => "PremiereEcouteMock",
      "chatter_user_id" => user_id,
      "chatter_user_login" => String.downcase(username),
      "chatter_user_name" => username,
      "message_id" => UUID.uuid4(),
      "message" => %{
        "text" => message,
        "fragments" => [
          %{
            "type" => "text",
            "text" => message,
            "cheermote" => nil,
            "emote" => nil,
            "mention" => nil
          }
        ]
      },
      "color" => "#9147FF",
      "badges" => [],
      "message_type" => "text",
      "cheer" => nil,
      "reply" => nil,
      "channel_points_custom_reward_id" => nil,
      "source_broadcaster_user_id" => nil,
      "source_broadcaster_user_login" => nil,
      "source_broadcaster_user_name" => nil,
      "source_message_id" => nil,
      "source_badges" => nil
    })

    json(conn, 200, %{status: "sent", message: message_data})
  end

  get "/eventsub/subscriptions" do
    subscriptions = Backend.get(:subscriptions, [])

    json(conn, 200, data(subscriptions, %{"total" => 0, "total_cost" => 0, "max_total_cost" => 10_000}))
  end

  post "/eventsub/subscriptions" do
    subscription = %{
      "id" => UUID.uuid4(),
      "status" => "webhook_callback_verification_pending",
      "type" => conn.body_params["type"],
      "version" => conn.body_params["version"],
      "cost" => 1,
      "condition" => conn.body_params["condition"],
      "transport" => Map.delete(conn.body_params["transport"], "secret"),
      "created_at" => DateTime.to_string(DateTime.utc_now())
    }

    Logger.info("Subscribing to #{subscription["type"]} - #{subscription["id"]}")
    Backend.update(:subscriptions, [], fn s -> s ++ [subscription] end)

    json(conn, 202, data(subscription, %{"total" => 1, "total_cost" => 1, "max_total_cost" => 10_000}))
  end

  delete "/eventsub/subscriptions" do
    subscriptions =
      Backend.update(:subscriptions, [], fn subs -> Enum.reject(subs, fn s -> s["id"] == conn.params["id"] end) end)

    Logger.info("Unsubscribing. Remaining subscriptions: #{inspect(subscriptions)}")

    no_content(conn)
  end

  get "/channels/followed" do
    json(conn, 200, data([], %{"total" => 0}))
  end

  get "/users" do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case user(token) do
          nil ->
            conn
            |> put_status(401)
            |> json(401, %{"error" => "Unauthorized", "status" => 401, "message" => "Invalid access token"})

          user_data ->
            json(conn, 200, data(user_data, %{}))
        end

      _ ->
        conn
        |> put_status(401)
        |> json(401, %{"error" => "Unauthorized", "status" => 401, "message" => "Invalid access token"})
    end
  end

  defp no_content(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(204, "")
  end

  defp json(conn, status, payload) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(payload))
  end

  defp data(payload, root) when is_list(payload), do: %{"data" => payload} |> Map.merge(root)
  defp data(payload, root), do: %{"data" => [payload]} |> Map.merge(root)

  # AIDEV-NOTE: validates real OAuth token against Twitch API and returns mock data for known users
  defp user(token) do
    client_id = Application.get_env(:premiere_ecoute, :twitch_client_id)

    Req.get(
      "https://api.twitch.tv/helix/users",
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"Client-Id", client_id}
      ]
    )
    |> case do
      {:ok, %{status: 200, body: %{"data" => [user_data | _]}}} ->
        user_data

      {:ok, %{status: 401}} ->
        Logger.warning("Invalid Twitch access token")
        nil

      {:error, reason} ->
        Logger.error("Failed to validate Twitch token: #{inspect(reason)}")
        nil
    end
  end

  defp send_webhook_notification(event_type, event_data) do
    broadcaster_user_id = event_data["broadcaster_user_id"] || "123456"

    Req.post(
      "http://localhost:4000/webhooks/twitch",
      json: %{
        "subscription" => %{
          "id" => UUID.uuid4(),
          "status" => "enabled",
          "type" => event_type,
          "version" => "1",
          "condition" => %{
            "broadcaster_user_id" => broadcaster_user_id,
            "user_id" => broadcaster_user_id
          },
          "transport" => %{
            "method" => "webhook",
            "callback" => "http://localhost:4000/webhooks/twitch"
          },
          "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
          "cost" => 0
        },
        "event" => event_data
      },
      headers: [
        {"Content-Type", "application/json"},
        {"Twitch-Eventsub-Message-Type", "notification"},
        {"Twitch-Eventsub-Message-Id", UUID.uuid4()},
        {"Twitch-Eventsub-Message-Timestamp", DateTime.to_iso8601(DateTime.utc_now())},
        {"Twitch-Eventsub-Subscription-Type", event_type},
        {"Twitch-Eventsub-Subscription-Version", "1"}
      ]
    )
  end
end
