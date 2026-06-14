defmodule PremiereEcoute.Podcasts.PodcastsFixtures do
  @moduledoc """
  Podcast fixtures.

  Provides factory functions for shows and episodes in test suites.
  """

  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Show
  alias PremiereEcoute.Repo

  @doc "Creates a Show fixture owned by `user`."
  @spec show_fixture(map(), map()) :: Show.t()
  def show_fixture(user, attrs \\ %{}) do
    default_attrs = %{
      user_id: user.id,
      title: "Test Show #{System.unique_integer([:positive])}",
      description: "A test podcast show",
      author: "Test Author",
      language: "en",
      category: "Music",
      explicit: false,
      cover_key: "podcasts/cover.png"
    }

    {:ok, show} =
      %Show{}
      |> Show.changeset(Map.merge(default_attrs, attrs))
      |> Repo.insert()

    Repo.preload(show, [:user])
  end

  @doc """
  Creates an Episode fixture for `show`. By default the episode is `:ready` and published so it
  appears in the feed; override `:status`/`:published_at` to build drafts.
  """
  @spec episode_fixture(Show.t(), map()) :: Episode.t()
  def episode_fixture(show, attrs \\ %{}) do
    n = System.unique_integer([:positive])

    default_attrs = %{
      show_id: show.id,
      title: "Episode #{n}",
      description: "Episode notes",
      audio_key: "podcasts/#{show.id}/episodes/#{Ecto.UUID.generate()}.mp3",
      audio_byte_size: 1_000_000,
      duration_seconds: 1800,
      status: :ready,
      published_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    {:ok, episode} =
      %Episode{}
      |> Episode.changeset(Map.merge(default_attrs, attrs))
      |> Repo.insert()

    Repo.preload(episode, show: [:user])
  end
end
