defmodule PremiereEcoute.Apis do
  @moduledoc """
  API facade module

  Provides convenient access to external API implementations. This module acts as a centralized entry point for retrieving configured API client instances.
  """

  alias PremiereEcoute.Apis.CurrencyApi
  alias PremiereEcoute.Apis.DeezerApi
  alias PremiereEcoute.Apis.SpotifyApi
  alias PremiereEcoute.Apis.TwitchApi

  def provider(:currency), do: CurrencyApi.impl()
  def provider(:deezer), do: DeezerApi.impl()
  def provider(:spotify), do: SpotifyApi.impl()
  def provider(:twitch), do: TwitchApi.impl()

  def currency, do: provider(:currency)
  def deezer, do: provider(:deezer)
  def spotify, do: provider(:spotify)
  def twitch, do: provider(:twitch)
end
