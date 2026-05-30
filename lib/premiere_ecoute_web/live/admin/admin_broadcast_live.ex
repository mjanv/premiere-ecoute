defmodule PremiereEcouteWeb.Admin.AdminBroadcastLive do
  @moduledoc """
  Admin broadcast LiveView.

  Allows admins to send manual chat messages or announcements via PremiereEcouteBot
  to a specific streamer's channel or to all streamers at once.
  """

  use PremiereEcouteWeb, :live_view

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.Streaming.TwitchApi.Chat

  @impl true
  def mount(_params, _session, socket) do
    streamers = Accounts.streamers()

    {:ok,
     socket
     |> assign(:streamers, streamers)
     |> assign(:target, "all")
     |> assign(:type, "chat")
     |> assign(:color, "purple")
     |> assign(:message, "")
     |> assign(:results, [])}
  end

  @impl true
  def handle_event("change", params, socket) do
    {:noreply,
     socket
     |> assign(:target, Map.get(params, "target", socket.assigns.target))
     |> assign(:type, Map.get(params, "type", socket.assigns.type))
     |> assign(:color, Map.get(params, "color", socket.assigns.color))
     |> assign(:message, Map.get(params, "message", socket.assigns.message))}
  end

  @impl true
  def handle_event("send", %{"message" => message, "target" => target, "type" => type} = params, socket) do
    color = Map.get(params, "color", "purple")
    message = String.trim(message)

    if message == "" do
      {:noreply, put_flash(socket, :error, gettext("Message cannot be empty"))}
    else
      results = do_send(socket.assigns.streamers, target, type, message, color)
      {:noreply, socket |> assign(:results, results) |> assign(:message, "")}
    end
  end

  # AIDEV-NOTE: sends synchronously — fine for small streamer counts; use Task.async_stream if it grows large
  defp do_send(streamers, "all", type, message, color) do
    streamers
    |> Enum.filter(&has_twitch?/1)
    |> Enum.map(&send_to_user(&1, type, message, color))
  end

  defp do_send(streamers, user_id, type, message, color) do
    case Enum.find(streamers, &(to_string(&1.id) == user_id)) do
      nil -> [{:error, "User not found"}]
      user -> [send_to_user(user, type, message, color)]
    end
  end

  defp send_to_user(user, "announcement", message, color) do
    scope = Scope.for_user(user)
    Chat.send_chat_announcement(scope, message, color)
    {:ok, user}
  rescue
    e -> {:error, "#{user.twitch.username}: #{Exception.message(e)}"}
  end

  defp send_to_user(user, _chat, message, _color) do
    scope = Scope.for_user(user)
    Chat.send_chat_message(scope, message)
    {:ok, user}
  rescue
    e -> {:error, "#{user.twitch.username}: #{Exception.message(e)}"}
  end

  defp has_twitch?(%{twitch: twitch}), do: not is_nil(twitch)
end
