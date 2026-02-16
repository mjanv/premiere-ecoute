defmodule PremiereEcoute.Apis.Streaming.TwitchApi.Users do
  @moduledoc """
  Twitch users API.

  Fetches Twitch user profile information from API.
  """

  require Logger

  alias PremiereEcoute.Apis.Streaming.TwitchApi

  @doc """
  Fetches Twitch user profile data.

  Retrieves authenticated user's profile information including ID, login name, display name, email, and broadcaster type.
  """
  @spec get_user_profile(String.t()) :: {:ok, map()} | {:error, term()}
  def get_user_profile(access_token) do
    access_token
    |> TwitchApi.api()
    |> TwitchApi.get(url: "/users")
    |> TwitchApi.handle(200, fn %{"data" => [user | _]} -> user end)
  end
end
