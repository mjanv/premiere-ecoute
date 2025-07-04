defmodule PremiereEcoute.Apis.TwitchApi.EventSub do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts.Scope

  def subscribe(%Scope{user: %{twitch_user_id: user_id, twitch_access_token: token}}, type) do
    "https://api.twitch.tv/helix/eventsub/subscriptions"
    |> Req.post(
      plug: {Req.Test, PremiereEcoute.Apis.TwitchApi},
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"Client-Id", Application.get_env(:premiere_ecoute, :twitch_client_id)},
        {"Content-Type", "application/json"}
      ],
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
      {:ok, %{status: 202, body: %{"data" => [poll | _]}}} ->
        {:ok, poll}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitch poll creation failed: #{status} - #{inspect(body)}")
        {:error, "Failed to create poll"}

      {:error, reason} ->
        Logger.error("Twitch poll request failed: #{inspect(reason)}")
        {:error, "Network error creating poll"}
    end
  end
end
