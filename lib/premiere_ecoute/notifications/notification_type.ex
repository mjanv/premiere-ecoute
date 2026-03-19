defmodule PremiereEcoute.Notifications.NotificationType do
  @moduledoc """
  Behaviour for notification types.

  Each type owns its data schema, rendering logic, and default delivery channels.
  Register new types in `Registry`.
  """

  @doc "Unique string key stored in user_notifications.type"
  @callback type() :: String.t()

  @doc "Default delivery channels for this notification type"
  @callback channels() :: [:pubsub | :email | :twitch_chat]

  @doc "Derives display content from the type struct"
  @callback render(struct()) :: %{
              title: String.t(),
              body: String.t(),
              icon: String.t(),
              path: String.t() | nil
            }
end
