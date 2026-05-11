defmodule PremiereEcoute.Collections.EventHandler do
  @moduledoc """
  GenServer that persists incoming Twitch reward redemptions into the collections cache.

  Subscribes to "twitch:events" PubSub and appends each %RewardRedeemed{} to the
  redemptions list of the matching active collection session. Broadcasts
  {:redemption_received, redemption} on "collection:{session_id}" so the LiveView updates.
  """

  use GenServer

  require Logger

  alias PremiereEcoute.Events.Twitch.RewardRedeemed
  alias PremiereEcoute.Twitch.Redemption
  alias PremiereEcouteCore.Cache

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init(_) do
    Phoenix.PubSub.subscribe(PremiereEcoute.PubSub, "twitch:events")
    {:ok, %{}}
  end

  @impl true
  def handle_info(
        %RewardRedeemed{broadcaster_id: broadcaster_id} = event,
        state
      ) do
    case Cache.get(:collections, broadcaster_id) do
      {:ok, %{session_id: session_id} = cached} ->
        redemption = %Redemption{
          id: event.id,
          broadcaster_id: event.broadcaster_id,
          user_id: event.user_id,
          user_login: event.user_login,
          reward_id: event.reward_id,
          reward_title: event.reward_title,
          user_input: event.user_input,
          status: :unfulfilled,
          redeemed_at: event.redeemed_at
        }

        updated = Map.update(cached, :redemptions, [redemption], &(&1 ++ [redemption]))

        case Cache.put(:collections, broadcaster_id, updated) do
          {:ok, _} ->
            PremiereEcoute.PubSub.broadcast("collection:#{session_id}", {:redemption_received, redemption})

          {:error, reason} ->
            Logger.warning("[Collections.EventHandler] cache write failed for broadcaster #{broadcaster_id}: #{inspect(reason)}")
        end

      _ ->
        Logger.debug(
          "[Collections.RedemptionHandler] no active session for broadcaster #{broadcaster_id}, dropping redemption #{event.id}"
        )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}
end
