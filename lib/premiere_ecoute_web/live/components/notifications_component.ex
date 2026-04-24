defmodule PremiereEcouteWeb.Live.Components.NotificationsComponent do
  @moduledoc """
  Live component rendering the notification bell and dropdown in the header.

  Loads unread notifications from DB on mount, subscribes to `"user:id"` PubSub
  for live updates, and handles mark-as-read actions.
  """

  use PremiereEcouteWeb, :live_component

  alias PremiereEcoute.Notifications

  @impl true
  def mount(socket) do
    {:ok, assign(socket, notifications: [], open: false)}
  end

  @impl true
  def update(%{incoming: {:user_notification, record, _rendered}}, socket) do
    {:ok, update(socket, :notifications, &[record | &1])}
  end

  def update(%{current_user: user} = assigns, socket) do
    notifications = Notifications.list_unread(user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(notifications: notifications)}
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    {:noreply, update(socket, :open, &(!&1))}
  end

  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, open: false)}
  end

  def handle_event("mark_all_read", _params, socket) do
    Notifications.mark_all_read(socket.assigns.current_user)
    {:noreply, assign(socket, notifications: [])}
  end

  def handle_event("mark_read", %{"id" => id}, socket) do
    id = String.to_integer(id)

    case Enum.find(socket.assigns.notifications, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      notification ->
        Notifications.mark_read(notification)
        notifications = Enum.reject(socket.assigns.notifications, &(&1.id == id))
        {:noreply, assign(socket, notifications: notifications)}
    end
  end

  defp notification_icon_bg("check-circle"), do: "bg-green-500/20"
  defp notification_icon_bg("heart"), do: "bg-pink-500/20"
  defp notification_icon_bg(_), do: "bg-red-500/20"

  defp notification_icon_color("check-circle"), do: "text-green-400"
  defp notification_icon_color("heart"), do: "text-pink-400"
  defp notification_icon_color(_), do: "text-red-400"

  defp notification_icon_path("check-circle"), do: "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"

  defp notification_icon_path("heart"),
    do:
      "M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"

  defp notification_icon_path(_),
    do:
      "M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"

  defp render_notification(notification) do
    case Notifications.get_type(notification.type) do
      {:ok, type_module} -> type_module.render(notification.data)
      :error -> %{title: notification.type, body: "", icon: "hero-bell", path: nil}
    end
  end

  defp unread_count(notifications), do: length(notifications)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative" id={@id} phx-target={@myself}>
      <!-- Bell button -->
      <button
        phx-click="toggle"
        phx-target={@myself}
        class="relative p-2 rounded-lg text-gray-400 hover:text-white hover:bg-gray-800 transition-colors"
        aria-label="Notifications"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
          />
        </svg>
        <%= if unread_count(@notifications) > 0 do %>
          <span class="absolute -top-0.5 -right-0.5 flex items-center justify-center w-4 h-4 text-xs font-bold text-white bg-red-500 rounded-full">
            {min(unread_count(@notifications), 9)}
          </span>
        <% end %>
      </button>
      
    <!-- Dropdown -->
      <%= if @open do %>
        <!-- Click-away overlay -->
        <div class="fixed inset-0 z-40" phx-click="close" phx-target={@myself}></div>

        <div
          class="absolute right-0 mt-2 w-80 rounded-lg shadow-xl border z-50 flex flex-col max-h-96"
          style="background-color: var(--color-dark-800); border-color: var(--color-dark-700);"
        >
          
    <!-- Header -->
          <div
            class="flex items-center justify-between px-4 py-3 border-b"
            style="border-color: var(--color-dark-700);"
          >
            <span class="text-sm font-semibold text-white">{gettext("Notifications")}</span>
            <%= if unread_count(@notifications) > 0 do %>
              <button
                phx-click="mark_all_read"
                phx-target={@myself}
                class="text-xs text-gray-400 hover:text-white transition-colors"
              >
                {gettext("Mark all read")}
              </button>
            <% end %>
          </div>
          
    <!-- List -->
          <div class="overflow-y-auto flex-1">
            <%= if @notifications == [] do %>
              <div class="flex flex-col items-center justify-center py-10 text-gray-500">
                <svg class="w-8 h-8 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="1.5"
                    d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
                  />
                </svg>
                <span class="text-sm">{gettext("No unread notifications")}</span>
              </div>
            <% else %>
              <%= for notification <- @notifications do %>
                <% rendered = render_notification(notification) %>
                <div
                  class="relative flex items-start gap-3 px-4 py-3 hover:bg-gray-700/40 transition-colors border-b last:border-0"
                  style="border-color: var(--color-dark-700);"
                >
                  <a
                    href={rendered.path || "#"}
                    phx-click="mark_read"
                    phx-value-id={notification.id}
                    phx-target={@myself}
                    class="absolute inset-0"
                  />
                  <!-- Icon -->
                  <div class={"flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center mt-0.5 relative z-10 pointer-events-none #{notification_icon_bg(rendered.icon)}"}>
                    <svg
                      class={"w-4 h-4 #{notification_icon_color(rendered.icon)}"}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d={notification_icon_path(rendered.icon)}
                      />
                    </svg>
                  </div>
                  <!-- Content -->
                  <div class="flex-1 min-w-0 relative z-10 pointer-events-none">
                    <p class="text-sm font-medium text-white truncate">{rendered.title}</p>
                    <p class="text-xs text-gray-400 mt-0.5 line-clamp-2">{rendered.body}</p>
                  </div>
                  <!-- Dismiss button -->
                  <button
                    phx-click="mark_read"
                    phx-value-id={notification.id}
                    phx-target={@myself}
                    class="flex-shrink-0 text-gray-600 hover:text-gray-300 transition-colors mt-0.5 relative z-10"
                    aria-label="Dismiss"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
