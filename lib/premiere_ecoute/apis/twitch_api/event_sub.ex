defmodule PremiereEcoute.Apis.TwitchApi.EventSub do
  @moduledoc false

  alias PremiereEcoute.Accounts.Bot
  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.TwitchApi
  alias PremiereEcouteCore.Cache

  def get_event_subscriptions(%Scope{user: %{twitch: %{user_id: user_id}}} = scope) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.get(url: "/eventsub/subscriptions", params: %{user_id: user_id})
    |> TwitchApi.handle(200, fn %{"data" => subscriptions} ->
      subscriptions
      |> Enum.map(fn s -> Map.take(s, ["id", "type"]) end)
      |> Enum.map(fn s ->
        Cache.put(:polls, {user_id, s["type"]}, s["id"])
        s
      end)
    end)
  end

  def subscribe(%Scope{user: %{twitch: %{user_id: user_id}}} = scope, type) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.post(
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
    |> TwitchApi.handle(202, fn %{"data" => [%{"id" => id} = poll | _]} ->
      Cache.put(:polls, {user_id, type}, id)
      poll
    end)
  end

  def unsubscribe(%Scope{user: %{twitch: %{user_id: user_id}}} = scope, type) do
    case Cache.get(:polls, {user_id, type}) do
      {:ok, id} when is_binary(id) ->
        scope
        |> TwitchApi.api()
        |> TwitchApi.delete(url: "/eventsub/subscriptions", params: %{"id" => id})
        |> TwitchApi.handle(204, fn _ -> id end)

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

  defp condition(%Scope{user: %{twitch: %{user_id: user_id}}}, "channel.chat.message") do
    bot = Bot.get()
    %{broadcaster_user_id: user_id, user_id: bot.twitch.user_id}
  end

  defp condition(%Scope{user: %{twitch: %{user_id: user_id}}}, "channel.follow"),
    do: %{broadcaster_user_id: user_id, moderator_user_id: user_id}

  defp condition(%Scope{user: %{twitch: %{user_id: user_id}}}, "channel.poll.progress"),
    do: %{broadcaster_user_id: user_id}

  defp condition(_, _), do: %{}
end
