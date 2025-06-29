defmodule PremiereEcoute.Apis.TwitchApi.EventSub do
  @moduledoc false

  require Logger

  def subscribe(broadcaster_id, token, session_id, type) do
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
        version: "1",
        condition: %{user_id: broadcaster_id},
        transport: %{
          method: "websocket",
          session_id: session_id
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
