defmodule PremiereEcoute.Apis.SpotifyApi.Users do
  @moduledoc false

  alias PremiereEcoute.Apis.SpotifyApi

  def get_user_profile(_scope) do
    SpotifyApi.api(:api)
    |> SpotifyApi.get(url: "/me")
    |> SpotifyApi.handle(200, &parse_profile/1)
  end

  defp parse_profile(body), do: Map.take(body, ["id", "display_name", "email", "country", "product"])
end
