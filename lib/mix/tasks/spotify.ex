defmodule Mix.Tasks.Spotify do
  @moduledoc false

  use Mix.Task

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
