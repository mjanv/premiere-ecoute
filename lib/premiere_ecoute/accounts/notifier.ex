defmodule PremiereEcoute.Accounts.Notifier do
  @moduledoc false

  use PremiereEcoute.Core.Subscriber, stream: "users"

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
