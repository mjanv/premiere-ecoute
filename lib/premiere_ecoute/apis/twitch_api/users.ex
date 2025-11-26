defmodule PremiereEcoute.Apis.TwitchApi.Users do
  @moduledoc """
  Twitch users API.

  Fetches Twitch user profile information from API.
  """

  require Logger

  alias PremiereEcoute.Apis.TwitchApi

  def get_user_profile(access_token) do
    access_token
    |> TwitchApi.api()
    |> TwitchApi.get(url: "/users")
    |> TwitchApi.handle(200, fn %{"data" => [user | _]} -> user end)
  end
end
