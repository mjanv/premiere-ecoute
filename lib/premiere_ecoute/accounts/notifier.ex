defmodule PremiereEcoute.Accounts.Notifier do
  @moduledoc """
  Account event notification subscriber.

  Subscribes to the users event stream and dispatches an email notification when a streamer account is created.
  """

  use PremiereEcouteCore.Subscriber, stream: "users"

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Events.AccountCreated

  @doc """
  Handles account events and dispatches email notifications.
  """
  @spec handle(EventStore.RecordedEvent.t()) :: any()
  def handle(%RecordedEvent{data: %AccountCreated{id: id} = event}) when is_integer(id) do
    case User.get(id) do
      %User{role: :streamer} -> PremiereEcoute.mailer().dispatch(event)
      _ -> :ok
    end
  end

  def handle(_event), do: :ok
end
