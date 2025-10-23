defmodule PremiereEcoute.Apis do
  @moduledoc """
  API facade module

  Provides convenient access to external API implementations. This module acts as a centralized entry point for retrieving configured API client instances.
  """

  alias PremiereEcoute.Apis.DeezerApi
  alias PremiereEcoute.Apis.FrankfurterApi
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.TwitchApi

  def provider(:deezer), do: DeezerApi.impl()
  def provider(:frankfurter), do: FrankfurterApi.impl()
  def provider(:spotify), do: SpotifyApi.impl()
  def provider(:twitch), do: TwitchApi.impl()

  def deezer, do: provider(:deezer)
  def frankfurter, do: provider(:frankfurter)
  def spotify, do: provider(:spotify)
  def twitch, do: provider(:twitch)
end
