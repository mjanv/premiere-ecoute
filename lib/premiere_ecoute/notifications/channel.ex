defmodule PremiereEcoute.Notifications.Channel do
  @moduledoc """
  Behaviour for notification delivery channels.

  Each channel receives the persisted notification record and the original
  typed struct for rendering.
  """

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Notifications.Notification

  @doc "Delivers a notification to the user via this channel."
  @callback deliver(User.t(), Notification.t(), struct()) :: :ok
end
