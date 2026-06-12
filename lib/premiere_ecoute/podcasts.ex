defmodule PremiereEcoute.Podcasts do
  @moduledoc """
  Podcasts context.

  Lets streamers self-host podcasts: a streamer owns one or more shows, uploads MP3 episodes,
  and each show is published as a public RSS feed consumable by any podcast app. See
  `docs/features/podcasts.md` for the full design.
  """

  use PremiereEcouteCore.Context

  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Events.ShowReported
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Image
  alias PremiereEcoute.Podcasts.Services.Feed
  alias PremiereEcoute.Podcasts.Show
  alias PremiereEcoute.Podcasts.Statistics
  alias PremiereEcoute.Podcasts.Storage
  alias PremiereEcoute.Podcasts.Workers.EpisodeIngestionWorker

  # Apple Podcasts requires square cover art between 1400×1400 and 3000×3000.
  @min_cover 1400
  @max_cover 3000

  # Shows
  defdelegate create_show(attrs), to: Show, as: :create
  defdelegate get_show(id), to: Show, as: :get
  defdelegate update_show(show, attrs), to: Show, as: :update
  defdelegate publish_show(show), to: Show, as: :publish
  defdelegate shows_for_user(user), to: Show, as: :all_for_user
  defdelegate get_published_show(username, slug), to: Show, as: :get_published
  defdelegate change_show(show, attrs \\ %{}), to: Show, as: :form

  # Episodes
  defdelegate create_episode(attrs), to: Episode, as: :create
  defdelegate get_episode(id), to: Episode, as: :get
  defdelegate update_episode(episode, attrs), to: Episode, as: :update
  defdelegate episodes_for_show(show), to: Episode, as: :all_for_show
  defdelegate feed_episodes(show), to: Episode
  defdelegate get_published_episode(show_id, guid), to: Episode, as: :get_published
  defdelegate mark_episode_ready(episode, attrs), to: Episode, as: :mark_ready
  defdelegate mark_episode_failed(episode), to: Episode, as: :mark_failed
  defdelegate publish_episode(episode), to: Episode, as: :publish
  defdelegate change_episode(episode, attrs \\ %{}), to: Episode, as: :form

  @doc "Renders the RSS feed XML for a show and its publishable episodes."
  @spec render_feed(Show.t(), map()) :: String.t()
  def render_feed(%Show{} = show, urls), do: Feed.render(show, feed_episodes(show), urls)

  @doc "Deletes an episode and removes its audio object from storage."
  @spec delete_episode(Episode.t()) :: {:ok, Episode.t()} | {:error, Ecto.Changeset.t()}
  def delete_episode(%Episode{audio_key: key} = episode) do
    if is_binary(key), do: Storage.delete(key)
    Episode.delete(episode)
  end

  @doc "Deletes a show (cascading episodes) and removes its audio + cover objects from storage."
  @spec delete_show(Show.t()) :: {:ok, Show.t()} | {:error, Ecto.Changeset.t()}
  def delete_show(%Show{} = show) do
    for %Episode{audio_key: key} <- episodes_for_show(show), is_binary(key), do: Storage.delete(key)
    if is_binary(show.cover_key), do: Storage.delete(show.cover_key)
    Show.delete(show)
  end

  @doc "Lists every show (admin moderation), most recently updated first."
  @spec all_shows() :: [Show.t()]
  def all_shows, do: Show.all(order_by: [desc: :updated_at])

  @doc "Unpublishes a show (admin takedown / streamer toggle)."
  @spec unpublish_show(Show.t()) :: {:ok, Show.t()} | {:error, Ecto.Changeset.t()}
  def unpublish_show(%Show{} = show), do: update_show(show, %{published: false})

  @doc "Removes an episode from its feed by clearing its publish date."
  @spec unpublish_episode(Episode.t()) :: {:ok, Episode.t()} | {:error, Ecto.Changeset.t()}
  def unpublish_episode(%Episode{} = episode), do: update_episode(episode, %{published_at: nil})

  @doc "Counts recorded downloads for an episode from the event store."
  @spec download_count(Episode.t() | integer()) :: non_neg_integer()
  def download_count(%Episode{id: id}), do: download_count(id)
  def download_count(id) when is_integer(id), do: length(Store.read("podcast_download-#{id}", :event))

  @doc "Lists every storage key (audio + cover) owned by a user — used to purge on account deletion."
  @spec user_storage_keys(User.t()) :: [String.t()]
  def user_storage_keys(%User{} = user) do
    shows = shows_for_user(user)
    covers = shows |> Enum.map(& &1.cover_key) |> Enum.filter(&is_binary/1)
    audios = shows |> Enum.flat_map(&episodes_for_show/1) |> Enum.map(& &1.audio_key) |> Enum.filter(&is_binary/1)
    covers ++ audios
  end

  @doc "Best-effort deletion of storage objects by key (account deletion / cleanup)."
  @spec purge_keys([String.t()]) :: :ok
  def purge_keys(keys) when is_list(keys), do: Enum.each(keys, &Storage.delete/1)

  @doc "Records an abuse/DMCA report against a show (surfaced to admins)."
  @spec report_show(Show.t(), String.t()) :: :ok
  def report_show(%Show{id: id}, reason), do: Store.append(%ShowReported{id: id, reason: reason}, stream: "podcast_report")

  @doc "Counts reports recorded against a show."
  @spec report_count(Show.t() | integer()) :: non_neg_integer()
  def report_count(%Show{id: id}), do: report_count(id)
  def report_count(id) when is_integer(id), do: length(Store.read("podcast_report-#{id}", :event))

  # Streamer-facing analytics (durable, from the Postgres event store)
  defdelegate episode_download_stats(episode), to: Statistics, as: :episode_downloads
  defdelegate show_download_stats(show), to: Statistics, as: :show_downloads
  defdelegate show_downloads_last(show, days), to: Statistics
  defdelegate episode_downloads_over_time(episode, unit, opts \\ []), to: Statistics
  defdelegate show_downloads_over_time(show, unit, opts \\ []), to: Statistics
  defdelegate unique_listeners(show_or_episode), to: Statistics

  @doc """
  Uploads an episode's audio and creates the episode in `:processing`, then enqueues ingestion to
  extract duration/byte size. The episode row is created (and validated) *before* the bytes are
  stored, so invalid metadata never leaves an orphaned object; a failed store marks it `:failed`.
  """
  @spec upload_episode(Show.t(), map(), binary()) :: {:ok, Episode.t()} | {:error, term()}
  def upload_episode(%Show{id: show_id}, attrs, bytes) when is_binary(bytes) do
    guid = Ecto.UUID.generate()
    key = Storage.audio_key(show_id, guid)
    attrs = Map.merge(attrs, %{show_id: show_id, guid: guid, audio_key: key, status: :processing})

    with {:ok, episode} <- create_episode(attrs),
         :ok <- store_audio(episode, key, bytes) do
      EpisodeIngestionWorker.start(%{id: episode.id})
      {:ok, episode}
    end
  end

  defp store_audio(episode, key, bytes) do
    case Storage.put(key, bytes) do
      :ok ->
        :ok

      {:error, reason} ->
        mark_episode_failed(episode)
        {:error, reason}
    end
  end

  @doc """
  Uploads a show cover image (after validating Apple's square ≥1400×1400 requirement) and stores
  its public URL on the show. Returns `{:error, :cover_too_small | :cover_too_large |
  :cover_not_square | atom()}` on rejection.
  """
  @spec upload_cover(Show.t(), String.t(), binary()) :: {:ok, Show.t()} | {:error, term()}
  def upload_cover(%Show{id: show_id} = show, ext, bytes) when is_binary(bytes) do
    with {:ok, {width, height}} <- Image.dimensions(bytes),
         :ok <- validate_cover(width, height) do
      key = Storage.cover_key(show_id, ext)

      with :ok <- Storage.put(key, bytes) do
        update_show(show, %{cover_key: key})
      end
    end
  end

  defp validate_cover(w, h) when w != h, do: {:error, :cover_not_square}
  defp validate_cover(w, h) when w < @min_cover or h < @min_cover, do: {:error, :cover_too_small}
  defp validate_cover(w, h) when w > @max_cover or h > @max_cover, do: {:error, :cover_too_large}
  defp validate_cover(_w, _h), do: :ok
end
