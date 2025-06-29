defmodule PremiereEcoute.Apis.TwitchApi.Polls do
  @moduledoc false

  require Logger

  # @impl true
  def create_poll(broadcaster_id, token, %{title: title, choices: choices}) do
    "https://api.twitch.tv/helix/polls"
    |> Req.post(
      plug: {Req.Test, PremiereEcoute.Apis.TwitchApi},
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"Client-Id", Application.get_env(:premiere_ecoute, :twitch_client_id)},
        {"Content-Type", "application/json"}
      ],
      json: %{
        broadcaster_id: broadcaster_id,
        title: title,
        choices: Enum.map(choices, fn choice -> %{title: choice} end),
        duration: 1800
      }
    )
    |> case do
      {:ok, %{status: 200, body: %{"data" => [poll | _]}}} ->
        {:ok, poll}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitch poll creation failed: #{status} - #{inspect(body)}")
        {:error, "Failed to create poll"}

      {:error, reason} ->
        Logger.error("Twitch poll request failed: #{inspect(reason)}")
        {:error, "Network error creating poll"}
    end
  end

  # @impl true
  def end_poll(broadcaster_id, token, poll_id) do
    "https://api.twitch.tv/helix/polls"
    |> Req.patch(
      plug: {Req.Test, PremiereEcoute.Apis.TwitchApi},
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"Client-Id", Application.get_env(:premiere_ecoute, :twitch_client_id)},
        {"Content-Type", "application/json"}
      ],
      json: %{
        broadcaster_id: broadcaster_id,
        id: poll_id,
        status: "TERMINATED"
      }
    )
    |> case do
      {:ok, %{status: 200, body: %{"data" => [poll | _]}}} ->
        {:ok, poll}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitch poll fetch failed: #{status} - #{inspect(body)}")
        {:error, "Failed to fetch poll results"}

      {:error, reason} ->
        Logger.error("Twitch poll request failed: #{inspect(reason)}")
        {:error, "Network error fetching poll"}
    end
  end

  def get_poll(broadcaster_id, token, poll_id) do
    "https://api.twitch.tv/helix/polls"
    |> Req.get(
      plug: {Req.Test, PremiereEcoute.Apis.TwitchApi},
      headers: [
        {"Authorization", "Bearer #{token}"},
        {"Client-Id", Application.get_env(:premiere_ecoute, :twitch_client_id)},
        {"Content-Type", "application/json"}
      ],
      params: %{
        broadcaster_id: broadcaster_id,
        id: poll_id
      }
    )
    |> case do
      {:ok, %{status: 200, body: %{"data" => [poll | _]}}} ->
        {:ok, poll}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Twitch poll fetch failed: #{status} - #{inspect(body)}")
        {:error, "Failed to fetch poll results"}

      {:error, reason} ->
        Logger.error("Twitch poll request failed: #{inspect(reason)}")
        {:error, "Network error fetching poll"}
    end
  end
end
