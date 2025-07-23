defmodule PremiereEcoute.Apis.TwitchApi.EventSub do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts.Bot
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.TwitchApi

  def get_event_subscriptions(%Scope{user: %{twitch_user_id: user_id}}) do
    TwitchApi.api(:helix)
    |> Req.get(
      url: "/eventsub/subscriptions",
      params: %{user_id: user_id}
    )
    |> case do
      {:ok, %{status: 200, body: %{"data" => subscriptions}}} ->
        subscriptions
        |> Enum.map(fn s -> Map.take(s, ["id", "type"]) end)
        |> Enum.map(fn s ->
          Cachex.put(:polls, {user_id, s["type"]}, s["id"])
          s
        end)
        |> then(fn subscriptions -> {:ok, subscriptions} end)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitch event subscriptions retrieval failed: #{status} - #{inspect(body)}")
        {:error, "Failed to retrieve event subscriptions"}

      {:error, reason} ->
        Logger.error("Twitch event subscriptions request failed: #{inspect(reason)}")
        {:error, "Network error retrieving event subscriptions"}
    end
  end

  def subscribe(%Scope{user: %{twitch_user_id: user_id}} = scope, type) do
    TwitchApi.api(:helix)
    |> Req.post(
      url: "/eventsub/subscriptions",
      json: %{
        type: type,
        version: version(type),
        condition: condition(scope, type),
        transport: %{
          method: "webhook",
          callback: Application.get_env(:premiere_ecoute, :twitch_webhook_callback_url),
          secret: Application.get_env(:premiere_ecoute, :twitch_eventsub_secret)
        }
      }
    )
    |> case do
      {:ok, %{status: 202, body: %{"data" => [%{"id" => id} = poll | _]}}} ->
        Cachex.put(:polls, {user_id, type}, id)
        {:ok, poll}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitch subscription creation failed: #{status} - #{inspect(body)}")
        {:error, "Failed to subscribe to #{type}"}

      {:error, reason} ->
        Logger.error("Twitch subscription request failed: #{inspect(reason)}")
        {:error, "Network error subscribing"}
    end
  end

  def unsubscribe(%Scope{user: %{twitch_user_id: user_id}}, type) do
    case Cachex.get(:polls, {user_id, type}) do
      {:ok, id} when is_binary(id) ->
        TwitchApi.api(:helix)
        |> Req.delete(
          url: "/eventsub/subscriptions",
          params: %{"id" => id}
        )
        |> case do
          {:ok, %{status: 204}} ->
            {:ok, id}

          {:ok, %{status: status}} ->
            Logger.error("Twitch unsubscribe failed: #{status}")
            {:error, "Failed to unsubscribe from #{type}"}

          {:error, reason} ->
            Logger.error("Twitch unsubscribe request failed: #{inspect(reason)}")
            {:error, "Network error unsubscribing"}
        end

      _ ->
        {:error, "Unknown subscription"}
    end
  end

  def cancel_all_subscriptions(scope) do
    case get_event_subscriptions(scope) do
      {:ok, subscriptions} ->
        results =
          subscriptions
          |> Enum.map(fn s -> unsubscribe(scope, s["type"]) end)

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
  defp version(_), do: "0"

  defp condition(%Scope{user: %{twitch_user_id: user_id}}, "channel.chat.message") do
    bot = Bot.get()
    %{broadcaster_user_id: user_id, user_id: bot.twitch_user_id}
  end

  defp condition(%Scope{user: %{twitch_user_id: user_id}}, "channel.follow"),
    do: %{broadcaster_user_id: user_id, moderator_user_id: user_id}

  defp condition(%Scope{user: %{twitch_user_id: user_id}}, "channel.poll.progress"),
    do: %{broadcaster_user_id: user_id}

  defp condition(_, _), do: %{}
end
