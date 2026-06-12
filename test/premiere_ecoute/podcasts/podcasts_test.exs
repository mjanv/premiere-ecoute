defmodule PremiereEcoute.PodcastsTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Events.EpisodeDownloaded
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Podcasts
  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Storage
  alias PremiereEcoute.Podcasts.Workers.EpisodeIngestionWorker

  # Agent-backed storage stub so uploads can be asserted without touching disk.
  defmodule MapStore do
    @behaviour PremiereEcoute.Podcasts.Storage

    def start_link, do: Agent.start_link(fn -> %{} end, name: __MODULE__)
    def fetch(key), do: Agent.get(__MODULE__, &Map.fetch(&1, key)) |> normalize()
    def put(key, bytes), do: Agent.update(__MODULE__, &Map.put(&1, key, bytes))
    def delete(key), do: Agent.update(__MODULE__, &Map.delete(&1, key)) && :ok

    defp normalize({:ok, bytes}), do: {:ok, bytes}
    defp normalize(:error), do: {:error, :not_found}
  end

  setup do
    {:ok, _} = MapStore.start_link()
    Application.put_env(:premiere_ecoute, Storage, adapter: MapStore, public_base_url: "https://cdn.test")
    on_exit(fn -> Application.delete_env(:premiere_ecoute, Storage) end)

    user = user_fixture()
    %{user: user, show: show_fixture(user)}
  end

  describe "upload_episode/3" do
    test "stores audio, creates a processing episode, and enqueues ingestion", %{show: show} do
      {:ok, episode} = Podcasts.upload_episode(show, %{"title" => "Ep 1", "description" => "notes"}, "AUDIOBYTES")

      assert episode.status == :processing
      assert episode.show_id == show.id
      assert episode.guid
      assert episode.audio_key == Storage.audio_key(show.id, episode.guid)
      assert {:ok, "AUDIOBYTES"} = Storage.fetch(episode.audio_key)
      assert_enqueued(worker: EpisodeIngestionWorker, args: %{id: episode.id})
    end
  end

  describe "delete_episode/1" do
    test "removes the episode and its stored audio", %{show: show} do
      {:ok, episode} = Podcasts.upload_episode(show, %{"title" => "Ep"}, "AUDIO")
      assert {:ok, "AUDIO"} = Storage.fetch(episode.audio_key)

      {:ok, _} = Podcasts.delete_episode(episode)

      assert is_nil(Episode.get(episode.id))
      assert {:error, _} = Storage.fetch(episode.audio_key)
    end
  end

  describe "upload_cover/3" do
    test "stores the cover and saves its public URL on the show", %{show: show} do
      {:ok, updated} = Podcasts.upload_cover(show, ".png", "IMGBYTES")

      assert updated.cover_url == Storage.public_url(Storage.cover_key(show.id, "png"))
      assert {:ok, "IMGBYTES"} = Storage.fetch(Storage.cover_key(show.id, "png"))
    end
  end

  describe "download_count/1" do
    test "counts EpisodeDownloaded events for the episode", %{show: show} do
      episode = episode_fixture(show)
      assert Podcasts.download_count(episode) == 0

      Store.append(%EpisodeDownloaded{id: episode.id, source: :feed}, stream: "podcast_download")
      Store.append(%EpisodeDownloaded{id: episode.id, source: :web}, stream: "podcast_download")

      assert Podcasts.download_count(episode) == 2
    end
  end

  describe "moderation helpers" do
    test "unpublish_show flips published to false", %{show: show} do
      {:ok, published} = Podcasts.publish_show(show)
      assert published.published

      {:ok, unpublished} = Podcasts.unpublish_show(published)
      refute unpublished.published
    end

    test "unpublish_episode clears the publish date", %{show: show} do
      episode = episode_fixture(show)
      assert episode.published_at

      {:ok, unpublished} = Podcasts.unpublish_episode(episode)
      assert is_nil(unpublished.published_at)
      assert is_nil(Episode.get(episode.id).published_at)
    end

    test "all_shows lists shows across users", %{show: show} do
      other = show_fixture(user_fixture())
      ids = Podcasts.all_shows() |> Enum.map(& &1.id)

      assert show.id in ids
      assert other.id in ids
    end
  end
end
