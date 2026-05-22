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
              required(:title) => String.t(),
              required(:body) => String.t(),
              required(:icon) => String.t(),
              required(:path) => String.t() | nil,
              optional(:target) => String.t()
            }
end
