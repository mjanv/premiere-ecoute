defmodule PremiereEcoute.Apis.Workers.SubscribeStreamEvents do
  @moduledoc """
  Subscribes all streamers to stream.online and stream.offline events.
  """

  use PremiereEcouteCore.Worker, queue: :twitch, max_attempts: 3

  require Logger

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.TwitchApi.EventSub

  @types ["stream.online", "stream.offline"]

  @impl true
  def perform(%Oban.Job{attempt: _attempt}) do
    Accounts.streamers()
    |> Enum.map(&subscribe_streamer/1)
    |> Enum.all?(fn status -> status == :ok end)
    |> case do
      true -> :ok
      false -> {:error, "Cannot subscribe to all streamers"}
    end
  end

  def subscribe_streamer(%User{twitch: %{username: username}} = user) do
    with _ <- Logger.info("Subscribing to events for streamer #{username}"),
         scope <- Scope.for_user(user),
         {:ok, subscriptions} <- EventSub.get_event_subscriptions(scope),
         types <- @types -- Enum.map(subscriptions, & &1["type"]),
         events <- Enum.map(types, &EventSub.subscribe(scope, &1)),
         true <- Enum.all?(events, fn {status, _} -> status == :ok end) do
      Logger.info("Subscribed all events streamer for streamer #{username}")
      :ok
    else
      {:error, reason} ->
        Logger.error("Failed to fetch existing subscriptions for streamer #{username}: #{inspect(reason)}")
        :error

      false ->
        Logger.error("Failed to subscribe to all events streamer for streamer #{username}")
        :error
    end
  end

  def subscribe_streamer(%User{}), do: :error
end
