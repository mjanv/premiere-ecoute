defmodule PremiereEcoute.Apis.TwitchApi.Channels do
  @moduledoc """
  Twitch channels API.

  Fetches followed channels for users from Twitch API.
  """

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.TwitchApi

  def get_followed_channels(%Scope{user: %{twitch: %{user_id: user_id}}} = scope) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.get(url: "/channels/followed", params: %{user_id: user_id})
    |> TwitchApi.handle(200, fn %{"data" => data} -> data end)
  end

  def get_followed_channel(%Scope{user: %{twitch: %{user_id: user_id}}} = scope, %User{
        twitch: %{user_id: streamer_id}
      }) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.get(url: "/channels/followed", params: %{user_id: user_id, broadcaster_id: streamer_id})
    |> TwitchApi.handle(200, fn
      %{"data" => []} -> nil
      %{"data" => [channel]} -> channel
    end)
  end
end
