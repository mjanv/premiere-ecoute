defmodule PremiereEcoute.Apis.TwitchApi.Polls do
  @moduledoc false

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.TwitchApi

  def create_poll(%Scope{user: %{twitch: %{user_id: broadcaster_id, access_token: token}}}, %{
        title: title,
        choices: choices,
        duration: duration
      }) do
    TwitchApi.api(:api, token)
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

  def end_poll(%Scope{user: %{twitch: %{user_id: broadcaster_id, access_token: token}}}, poll_id) do
    TwitchApi.api(:api, token)
    |> TwitchApi.patch(url: "/polls", json: %{broadcaster_id: broadcaster_id, id: poll_id, status: "TERMINATED"})
    |> TwitchApi.handle(200, fn %{"data" => [poll | _]} -> poll end)
  end

  def get_poll(%Scope{user: %{twitch: %{user_id: broadcaster_id, access_token: token}}}, poll_id) do
    TwitchApi.api(:api, token)
    |> TwitchApi.get(url: "/polls", params: %{broadcaster_id: broadcaster_id, id: poll_id})
    |> TwitchApi.handle(200, fn %{"data" => [poll | _]} -> poll end)
  end
end
