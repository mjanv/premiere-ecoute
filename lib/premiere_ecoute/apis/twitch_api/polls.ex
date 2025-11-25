defmodule PremiereEcoute.Apis.TwitchApi.Polls do
  @moduledoc """
  Twitch polls API.

  Creates, ends, and retrieves Twitch channel polls for viewer voting.
  """

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.TwitchApi

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

  def end_poll(%Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope, poll_id) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.patch(url: "/polls", json: %{broadcaster_id: broadcaster_id, id: poll_id, status: "TERMINATED"})
    |> TwitchApi.handle(200, fn %{"data" => [poll | _]} -> poll end)
  end

  def get_poll(%Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope, poll_id) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.get(url: "/polls", params: %{broadcaster_id: broadcaster_id, id: poll_id})
    |> TwitchApi.handle(200, fn %{"data" => [poll | _]} -> poll end)
  end
end
