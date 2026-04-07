defmodule PremiereEcoute.Apis do
  @moduledoc """
  API facade module

  Provides convenient access to external API implementations. This module acts as a centralized entry point for retrieving configured API client instances.
  """

  alias PremiereEcoute.Apis.MusicMetadata.GeniusApi
  alias PremiereEcoute.Apis.MusicMetadata.MusicBrainzApi
  alias PremiereEcoute.Apis.MusicMetadata.WikipediaApi

  alias PremiereEcoute.Apis.MusicProvider.DeezerApi
  alias PremiereEcoute.Apis.MusicProvider.SpotifyApi
  alias PremiereEcoute.Apis.MusicProvider.TidalApi

  alias PremiereEcoute.Apis.Streaming.TwitchApi

  alias PremiereEcoute.Apis.Video.YoutubeApi

  @type music_metadata :: :genius | :musicbrainz | :wikipedia
  @type music_provider :: :deezer | :spotify | :tidal
  @type streaming :: :twitch
  @type video :: :youtube

  @type provider :: music_metadata() | music_provider() | streaming() | video()
  @providers [:genius, :musicbrainz, :wikipedia, :deezer, :spotify, :tidal, :twitch, :youtube]

  @doc "Returns the API client module for the specified provider."
  @spec provider(provider()) :: module()
  def provider(:genius), do: GeniusApi.impl()
  def provider(:musicbrainz), do: MusicBrainzApi.impl()
  def provider(:wikipedia), do: WikipediaApi.impl()

  def provider(:deezer), do: DeezerApi.impl()
  def provider(:spotify), do: SpotifyApi.impl()
  def provider(:tidal), do: TidalApi.impl()

  def provider(:twitch), do: TwitchApi.impl()

  def provider(:youtube), do: YoutubeApi.impl()

  for provider_name <- @providers do
    @doc "Returns the #{provider_name} API client."
    @spec unquote(provider_name)() :: module()
    def unquote(provider_name)(), do: provider(unquote(provider_name))
  end

  def cache(:spotify), do: PremiereEcoute.Apis.Players.PlaybackState
end
