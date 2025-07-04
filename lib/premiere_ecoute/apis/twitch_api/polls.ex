defmodule PremiereEcoute.Apis.TwitchApi.Polls do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.TwitchApi

  def create_poll(%Scope{user: %{twitch_user_id: broadcaster_id, twitch_access_token: token}}, %{
        title: title,
        choices: choices,
        duration: duration
      }) do
    TwitchApi.api(:helix, token)
    |> Req.post(
      url: "/polls",
      json: %{
        broadcaster_id: broadcaster_id,
        title: title,
        choices: Enum.map(choices, fn choice -> %{title: choice} end),
        duration: duration
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

  def end_poll(
        %Scope{user: %{twitch_user_id: broadcaster_id, twitch_access_token: token}},
        poll_id
      ) do
    TwitchApi.api(:helix, token)
    |> Req.patch(
      url: "/polls",
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

  def get_poll(
        %Scope{user: %{twitch_user_id: broadcaster_id, twitch_access_token: token}},
        poll_id
      ) do
    TwitchApi.api(:helix, token)
    |> Req.get(
      url: "/polls",
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
