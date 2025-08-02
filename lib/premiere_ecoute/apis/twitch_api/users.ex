defmodule PremiereEcoute.Apis.TwitchApi.Users do
  @moduledoc false

  require Logger

  alias PremiereEcoute.Apis.TwitchApi

  def get_user_profile(access_token) do
    TwitchApi.api(:api, access_token)
    |> TwitchApi.get(url: "/users")
    |> TwitchApi.handle(200, fn %{"data" => [user | _]} -> user end)
  end
end
