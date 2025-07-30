defmodule Mix.Tasks.Spotify.Url do
  @moduledoc false

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
