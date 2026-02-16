defmodule PremiereEcoute.Apis.Streaming.TwitchApi.Polls do
  @moduledoc """
  Twitch polls API.

  Creates, ends, and retrieves Twitch channel polls for viewer voting.
  """

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.Streaming.TwitchApi

  @doc """
  Creates poll in broadcaster's Twitch channel.

  Starts interactive poll with title, multiple choice options, and duration in seconds for viewer voting.
  """
  @spec create_poll(Scope.t(), map()) :: {:ok, map()} | {:error, term()}
  def create_poll(%Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope, %{
        title: title,
        choices: choices,
        duration: duration
      }) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.post(
      url: "/polls",
      json: %{
        broadcaster_id: broadcaster_id,
        title: title,
        choices: Enum.map(choices, fn choice -> %{title: choice} end),
        duration: duration
      }
    )
    |> TwitchApi.handle(200, fn %{"data" => [poll | _]} -> poll end)
  end

  @doc """
  Terminates active poll immediately.

  Ends poll before duration expires and returns final results with vote counts.
  """
  @spec end_poll(Scope.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def end_poll(%Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope, poll_id) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.patch(url: "/polls", json: %{broadcaster_id: broadcaster_id, id: poll_id, status: "TERMINATED"})
    |> TwitchApi.handle(200, fn %{"data" => [poll | _]} -> poll end)
  end

  @doc """
  Retrieves poll data by ID.

  Fetches poll information including status, choices, and current vote counts.
  """
  @spec get_poll(Scope.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_poll(%Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope, poll_id) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.get(url: "/polls", params: %{broadcaster_id: broadcaster_id, id: poll_id})
    |> TwitchApi.handle(200, fn %{"data" => [poll | _]} -> poll end)
  end
end
