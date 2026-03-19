defmodule PremiereEcoute.Notifications.Dispatcher do
  @moduledoc """
  Persists a notification then routes it to all declared delivery channels.

  Accepts a notification type struct. The struct is serialised to `type` (string)
  and `data` (map) for DB persistence. Channels receive the original struct for rendering.
  """

  alias PremiereEcoute.Notifications.Channels.PubSubChannel
  alias PremiereEcoute.Notifications.{Notification, Registry}

  @doc """
  Persists and dispatches a notification to all channels declared by the type.

  Returns `{:error, :unknown_type}` for unregistered struct types.
  """
  @spec dispatch(User.t(), struct()) :: {:ok, Notification.t()} | {:error, term()}
  def dispatch(user, notification) do
    with {:ok, type_module} <- Registry.get(notification),
         {:ok, record} <- Notification.insert(user, type_module.type(), Map.from_struct(notification)),
         :ok <- Enum.each(type_module.channels(), &channel(&1).deliver(user, record, notification)) do
      {:ok, record}
    else
      :error -> {:error, :unknown_type}
      {:error, reason} -> {:error, reason}
    end
  end

  defp channel(:pubsub), do: PubSubChannel
end
