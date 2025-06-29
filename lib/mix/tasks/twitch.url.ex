defmodule Mix.Tasks.Twitch.Url do
  @moduledoc false

  use Mix.Task

  alias PremiereEcoute.Apis.TwitchApi

  def run(_) do
    Application.put_env(:premiere_ecoute, :twitch_client_id, System.get_env("TWITCH_CLIENT_ID"))

    Application.put_env(
      :premiere_ecoute,
      :twitch_redirect_uri,
      System.get_env("TWITCH_REDIRECT_URI")
    )

    Mix.shell().info("#{TwitchApi.authorization_url()}")
  end
end
