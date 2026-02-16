defmodule PremiereEcoute.Apis.Streaming.TwitchApi.Channels do
  @moduledoc """
  Twitch channels API.

  Fetches followed channels for users from Twitch API.
  """

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Apis.Streaming.TwitchApi

  @doc """
  Retrieves all channels followed by the user.

  Fetches list of Twitch channels the authenticated user follows.
  """
  @spec get_followed_channels(Scope.t()) :: {:ok, list(map())} | {:error, term()}
  def get_followed_channels(%Scope{user: %{twitch: %{user_id: user_id}}} = scope) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.get(url: "/channels/followed", params: %{user_id: user_id})
    |> TwitchApi.handle(200, fn %{"data" => data} -> data end)
  end

  @doc """
  Checks if user follows specific channel.

  Returns channel data if user follows the specified broadcaster, nil otherwise.
  """
  @spec get_followed_channel(Scope.t(), User.t()) :: {:ok, map() | nil} | {:error, term()}
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
