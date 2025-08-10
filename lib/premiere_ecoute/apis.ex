defmodule PremiereEcoute.Apis do
  @moduledoc """
  API facade module

  Provides convenient access to external API implementations including Spotify and Twitch services. This module acts as a centralized entry point for retrieving configured API client instances.
  """

  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.TwitchApi

  def provider(:spotify), do: SpotifyApi.impl()
  def provider(:twitch), do: TwitchApi.impl()

  def spotify, do: provider(:spotify)
  def twitch, do: provider(:twitch)
end
