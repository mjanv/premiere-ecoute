defmodule PremiereEcoute.Notifications.Channels.PubSubChannel do
  @moduledoc "Delivers notifications via PubSub broadcast to the user's live session."

  @behaviour PremiereEcoute.Notifications.Channel

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Notifications.{Notification, Registry}

  @impl true
  def deliver(%User{} = user, %Notification{} = record, notification) do
    {:ok, type_module} = Registry.get(notification)
    rendered = type_module.render(notification)

    PremiereEcoute.PubSub.broadcast(
      "user:#{user.id}",
      {:user_notification, record, rendered}
    )
  end
end
