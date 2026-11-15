defmodule PremiereEcoute.Wrapped.Subscriber do
  @moduledoc """
  Wrapped event subscriber.

  Subscribes to the users event stream and, during the campaign, enqueues the recap of a user as soon as they link their Twitch account: their votes are keyed on their Twitch id, so a newcomer already has a history.
  """

  use PremiereEcouteCore.Subscriber, stream: "users"

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Events.AccountAssociated
  alias PremiereEcoute.Wrapped.Recap
  alias PremiereEcoute.Wrapped.Services.ComputeRecap

  @doc """
  Handles account events and requests the recap of a user who linked Twitch.
  """
  @spec handle(EventStore.RecordedEvent.t()) :: :ok
  def handle(%RecordedEvent{data: %AccountAssociated{id: id, provider: provider}})
      when is_integer(id) and provider in [:twitch, "twitch"] do
    with year when not is_nil(year) <- Recap.campaign_year(),
         %User{} = user <- User.get(id) do
      ComputeRecap.ensure(user)
    end

    :ok
  end

  def handle(_event), do: :ok
end
