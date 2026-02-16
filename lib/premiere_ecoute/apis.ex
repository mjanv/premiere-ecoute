defmodule PremiereEcoute.Apis do
  @moduledoc """
  API facade module

  Provides convenient access to external API implementations. This module acts as a centralized entry point for retrieving configured API client instances.
  """

  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.Payments.FrankfurterApi
  alias PremiereEcoute.Apis.Streaming.TwitchApi

  @doc "Returns the API client module for the specified provider."
  @spec provider(:deezer | :frankfurter | :spotify | :twitch) :: module()
  def provider(:deezer), do: DeezerApi.impl()
  def provider(:frankfurter), do: FrankfurterApi.impl()
  def provider(:spotify), do: SpotifyApi.impl()
  def provider(:twitch), do: TwitchApi.impl()

  @doc "Returns the Deezer API client."
  @spec deezer() :: module()
  def deezer, do: provider(:deezer)

  @doc "Returns the Frankfurter API client."
  @spec frankfurter() :: module()
  def frankfurter, do: provider(:frankfurter)

  @doc "Returns the Spotify API client."
  @spec spotify() :: module()
  def spotify, do: provider(:spotify)

  @doc "Returns the Twitch API client."
  @spec twitch() :: module()
  def twitch, do: provider(:twitch)
end
