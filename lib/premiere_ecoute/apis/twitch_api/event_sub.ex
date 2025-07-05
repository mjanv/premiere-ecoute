defmodule PremiereEcoute.Apis.TwitchApi.EventSub do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.TwitchApi

  def subscribe(%Scope{user: %{twitch_user_id: user_id}}, type) do
    TwitchApi.api(:helix)
    |> Req.post(
      url: "/eventsub/subscriptions",
      json: %{
        type: type,
        version: "2",
        condition: %{broadcaster_user_id: user_id, moderator_user_id: user_id},
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
        Logger.error("Twitch poll creation failed: #{status} - #{inspect(body)}")
        {:error, "Failed to create poll"}

      {:error, reason} ->
        Logger.error("Twitch poll request failed: #{inspect(reason)}")
        {:error, "Network error creating poll"}
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
            Logger.error("Twitch poll creation failed: #{status}")
            {:error, "Failed to delete poll"}

          {:error, reason} ->
            Logger.error("Twitch poll request failed: #{inspect(reason)}")
            {:error, "Network error deleting poll"}
        end

      _ ->
        {:error, "Unknown subscription"}
    end
  end
end
