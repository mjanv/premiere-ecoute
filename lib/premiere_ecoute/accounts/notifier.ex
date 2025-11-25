defmodule PremiereEcoute.Accounts.Notifier do
  @moduledoc """
  Account event notification subscriber.

  Subscribes to the users event stream and dispatches email notifications for account creation and deletion events.
  """

  use PremiereEcouteCore.Subscriber, stream: "users"

  alias PremiereEcoute.Events.AccountCreated
  alias PremiereEcoute.Events.AccountDeleted

  def handle(%RecordedEvent{data: event}) do
    case event do
      %AccountCreated{} = event -> PremiereEcoute.mailer().dispatch(event)
      %AccountDeleted{} = event -> PremiereEcoute.mailer().dispatch(event)
      _ -> :ok
    end
  end
end
