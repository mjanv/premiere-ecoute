defmodule PremiereEcoute.Apis do
  @moduledoc """
  API facade module

  Provides convenient access to external API implementations. This module acts as a centralized entry point for retrieving configured API client instances.
  """

  use PremiereEcouteCore.Context

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

  @doc "Returns the genius API client."
  @spec genius() :: module()
  def genius, do: provider(:genius)

  @doc "Returns the musicbrainz API client."
  @spec musicbrainz() :: module()
  def musicbrainz, do: provider(:musicbrainz)

  @doc "Returns the wikipedia API client."
  @spec wikipedia() :: module()
  def wikipedia, do: provider(:wikipedia)

  @doc "Returns the deezer API client."
  @spec deezer() :: module()
  def deezer, do: provider(:deezer)

  @doc "Returns the spotify API client."
  @spec spotify() :: module()
  def spotify, do: provider(:spotify)

  @doc "Returns the tidal API client."
  @spec tidal() :: module()
  def tidal, do: provider(:tidal)

  @doc "Returns the twitch API client."
  @spec twitch() :: module()
  def twitch, do: provider(:twitch)

  @doc "Returns the youtube API client."
  @spec youtube() :: module()
  def youtube, do: provider(:youtube)

  @doc """
  Returns the cache module holding the playback state of a provider.
  """
  @spec cache(:spotify) :: module()
  def cache(:spotify), do: PremiereEcoute.Apis.Players.PlaybackState
end
