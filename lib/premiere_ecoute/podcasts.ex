defmodule PremiereEcoute.Podcasts do
  @moduledoc """
  Podcasts context.

  Lets streamers self-host podcasts: a streamer owns one or more shows, uploads MP3 episodes,
  and each show is published as a public RSS feed consumable by any podcast app. See
  `docs/features/podcasts.md` for the full design.
  """

  use PremiereEcouteCore.Context

  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Services.Feed
  alias PremiereEcoute.Podcasts.Show

  # Shows
  defdelegate create_show(attrs), to: Show, as: :create
  defdelegate get_show(id), to: Show, as: :get
  defdelegate update_show(show, attrs), to: Show, as: :update
  defdelegate delete_show(show), to: Show, as: :delete
  defdelegate publish_show(show), to: Show, as: :publish
  defdelegate shows_for_user(user), to: Show, as: :all_for_user
  defdelegate get_published_show(username, slug), to: Show, as: :get_published

  # Episodes
  defdelegate create_episode(attrs), to: Episode, as: :create
  defdelegate get_episode(id), to: Episode, as: :get
  defdelegate update_episode(episode, attrs), to: Episode, as: :update
  defdelegate delete_episode(episode), to: Episode, as: :delete
  defdelegate episodes_for_show(show), to: Episode, as: :all_for_show
  defdelegate feed_episodes(show), to: Episode
  defdelegate get_published_episode(show_id, guid), to: Episode, as: :get_published
  defdelegate mark_episode_ready(episode, attrs), to: Episode, as: :mark_ready
  defdelegate mark_episode_failed(episode), to: Episode, as: :mark_failed
  defdelegate publish_episode(episode), to: Episode, as: :publish

  @doc "Renders the RSS feed XML for a show and its publishable episodes."
  @spec render_feed(Show.t(), map()) :: String.t()
  def render_feed(%Show{} = show, urls), do: Feed.render(show, feed_episodes(show), urls)
end
