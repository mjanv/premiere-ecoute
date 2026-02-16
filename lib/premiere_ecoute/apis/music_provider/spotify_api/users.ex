defmodule PremiereEcoute.Apis.MusicProvider.SpotifyApi.Users do
  @moduledoc """
  Spotify users API.

  Fetches Spotify user profile information including ID, display name, email, country, and product subscription.
  """

  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi

  @doc """
  Fetches Spotify user profile.

  Retrieves authenticated user's profile information including ID, display name, email, country, and product subscription tier.
  """
  @spec get_user_profile(String.t()) :: {:ok, map()} | {:error, term()}
  def get_user_profile(access_token) do
    SpotifyApi.api(access_token)
    |> SpotifyApi.get(url: "/me")
    |> SpotifyApi.handle(200, &parse_profile/1)
  end

  defp parse_profile(body), do: Map.take(body, ["id", "display_name", "email", "country", "product"])
end
