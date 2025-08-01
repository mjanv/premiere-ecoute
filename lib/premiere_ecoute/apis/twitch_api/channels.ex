defmodule PremiereEcoute.Apis.TwitchApi.Channels do
  @moduledoc false

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.TwitchApi

  def get_followed_channels(%Scope{user: %{twitch_user_id: user_id, twitch_access_token: token}}) do
    TwitchApi.api(:api, token)
    |> TwitchApi.get(url: "/channels/followed", params: %{user_id: user_id})
    |> TwitchApi.handle(200, fn %{"data" => data} -> data end)
  end

  def get_followed_channel(%Scope{user: %{twitch_user_id: user_id, twitch_access_token: token}}, %User{
        twitch_user_id: streamer_id
      }) do
    TwitchApi.api(:api, token)
    |> TwitchApi.get(url: "/channels/followed", params: %{user_id: user_id, broadcaster_id: streamer_id})
    |> TwitchApi.handle(200, fn
      %{"data" => []} -> nil
      %{"data" => [channel]} -> channel
    end)
  end
end
