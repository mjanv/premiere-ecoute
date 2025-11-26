defmodule Mix.Tasks.Spotify.Url do
  @moduledoc """
  Generates the Spotify OAuth authorization URL.

  ## Usage

      mix spotify.url

  Requires `SPOTIFY_CLIENT_ID` and `SPOTIFY_REDIRECT_URI` environment variables.
  """

  use Mix.Task
  use Boundary, classify_to: PremiereEcouteMix

  alias PremiereEcoute.Apis.SpotifyApi

  def run(_) do
    Application.put_env(:premiere_ecoute, :spotify_client_id, System.get_env("SPOTIFY_CLIENT_ID"))

    Application.put_env(
      :premiere_ecoute,
      :spotify_redirect_uri,
      System.get_env("SPOTIFY_REDIRECT_URI")
    )

    Mix.shell().info("#{SpotifyApi.authorization_url()}")
  end
end
