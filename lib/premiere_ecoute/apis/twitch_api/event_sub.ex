defmodule PremiereEcoute.Apis.TwitchApi.EventSub do
  @moduledoc """
  Twitch EventSub subscription management.

  Manages Twitch EventSub webhook subscriptions for chat messages, follows, polls, and stream status. Handles subscription creation/cancellation with proper conditions and caches subscription IDs.
  """

  require Logger

  alias PremiereEcoute.Accounts.Bot
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.TwitchApi
  alias PremiereEcouteCore.Cache

  @secret Application.compile_env(:premiere_ecoute, :twitch_eventsub_secret)

  @doc """
  Retrieves all EventSub subscriptions for user.

  Fetches active webhook subscriptions and caches subscription IDs for efficient cancellation.
  """
  @spec get_event_subscriptions(Scope.t()) :: {:ok, list(map())} | {:error, term()}
  def get_event_subscriptions(%Scope{user: %{twitch: %{user_id: user_id}}}) do
    TwitchApi.api()
    |> TwitchApi.get(url: "/eventsub/subscriptions", params: %{user_id: user_id})
    |> TwitchApi.handle(200, fn %{"data" => subscriptions} ->
      Enum.each(subscriptions, fn s -> Cache.put(:subscriptions, {user_id, s["type"]}, s["id"]) end)
      subscriptions
    end)
  end

  @doc """
  Creates EventSub webhook subscription for event type.

  Subscribes to Twitch event notifications (chat messages, follows, polls, streams) with appropriate conditions. Caches subscription ID.
  """
  @spec subscribe(Scope.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def subscribe(%Scope{user: %{twitch: %{user_id: user_id}}} = scope, type) do
    TwitchApi.api()
    |> TwitchApi.post(
      url: "/eventsub/subscriptions",
      json: %{
        type: type,
        version: version(type),
        condition: condition(scope, type),
        transport: %{
          method: "webhook",
          callback: Application.get_env(:premiere_ecoute, :twitch_webhook_callback_url),
          secret: @secret
        }
      }
    )
    |> TwitchApi.handle(202, fn %{"data" => [%{"id" => id} = poll | _]} ->
      Cache.put(:subscriptions, {user_id, type}, id)
      poll
    end)
  end

  @doc """
  Cancels EventSub subscription for event type.

  Removes webhook subscription using cached subscription ID. If subscription is not in cache, fetches current subscriptions from Twitch to sync cache, then attempts unsubscribe. Returns subscription ID on success, or :no_subscription if no subscription exists (idempotent).
  """
  @spec unsubscribe(Scope.t(), String.t()) :: {:ok, String.t() | :no_subscription} | {:error, term()}
  def unsubscribe(%Scope{user: %{twitch: %{user_id: user_id}}} = scope, type) do
    case Cache.get(:subscriptions, {user_id, type}) do
      {:ok, id} when is_binary(id) ->
        delete_subscription(id)

      _ ->
        with {:ok, _subscriptions} <- get_event_subscriptions(scope),
             {:ok, id} when is_binary(id) <- Cache.get(:subscriptions, {user_id, type}) do
          delete_subscription(id)
        else
          _ ->
            {:ok, :no_subscription}
        end
    end
  end

  defp delete_subscription(id) do
    TwitchApi.api()
    |> TwitchApi.delete(url: "/eventsub/subscriptions", params: %{"id" => id})
    |> TwitchApi.handle([204, 404], fn _ -> id end)
  end

  @doc """
  Cancels all EventSub subscriptions for user.

  Fetches and cancels all active webhook subscriptions. Returns list of cancelled subscription IDs on success.
  """
  @spec cancel_all_subscriptions(Scope.t()) :: {:ok, list(String.t())} | {:error, term()}
  def cancel_all_subscriptions(scope) do
    case get_event_subscriptions(scope) do
      {:ok, subscriptions} ->
        results = Enum.map(subscriptions, fn s -> unsubscribe(scope, s["type"]) end)

        case Enum.all?(results, fn {status, _} -> status == :ok end) do
          true -> {:ok, Enum.map(results, fn {_, id} -> id end)}
          false -> {:error, "Cannot cancel all subscriptions"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp version("channel.chat.message"), do: "1"
  defp version("channel.follow"), do: "2"
  defp version("channel.poll.progress"), do: "1"
  defp version("stream.online"), do: "1"
  defp version("stream.offline"), do: "1"
  defp version(_), do: "0"

  defp condition(%Scope{user: %{twitch: %{user_id: user_id}}}, "channel.chat.message") do
    {:ok, bot} = Bot.get()
    %{broadcaster_user_id: user_id, user_id: bot.twitch.user_id}
  end

  defp condition(%Scope{user: %{twitch: %{user_id: user_id}}}, "channel.follow"),
    do: %{broadcaster_user_id: user_id, moderator_user_id: user_id}

  defp condition(%Scope{user: %{twitch: %{user_id: user_id}}}, "channel.poll.progress"),
    do: %{broadcaster_user_id: user_id}

  defp condition(%Scope{user: %{twitch: %{user_id: user_id}}}, "stream.online"),
    do: %{broadcaster_user_id: user_id}

  defp condition(%Scope{user: %{twitch: %{user_id: user_id}}}, "stream.offline"),
    do: %{broadcaster_user_id: user_id}

  defp condition(_, _), do: %{}
end
