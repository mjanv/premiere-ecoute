defmodule PremiereEcoute.Notifications do
  @moduledoc """
  Public context for the notification system.

  All other contexts call `dispatch/3` to persist and deliver notifications.
  The system is channel-agnostic: types declare their channels, the dispatcher routes.
  """

  alias PremiereEcoute.Notifications.{Dispatcher, Notification, Registry}

  @doc "Persists and dispatches a notification struct. Returns `{:error, :unknown_type}` for unknown types."
  defdelegate dispatch(user, notification), to: Dispatcher

  @doc "Unread notifications for a user, ordered by recency."
  defdelegate list_unread(user), to: Notification

  @doc "Unread notification count for a user."
  defdelegate unread_count(user), to: Notification

  @doc "Marks a single notification as read."
  defdelegate mark_read(notification), to: Notification

  @doc "Marks all notifications for a user as read."
  defdelegate mark_all_read(user), to: Notification

  @doc "Looks up a notification type module by its string key."
  defdelegate get_type(type_string), to: Registry, as: :get_by_string
end
