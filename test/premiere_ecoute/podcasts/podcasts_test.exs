defmodule PremiereEcoute.PodcastsTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Events.PodcastEpisodeDownloaded
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Podcasts
  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Storage

  # Agent-backed storage stub so uploads can be asserted without touching disk.
  defmodule MapStore do
    @behaviour PremiereEcoute.Podcasts.Storage

    def start_link, do: Agent.start_link(fn -> %{} end, name: __MODULE__)
    def fetch(key), do: Agent.get(__MODULE__, &Map.fetch(&1, key)) |> normalize()
    def put(key, bytes), do: Agent.update(__MODULE__, &Map.put(&1, key, bytes))
    def delete(key), do: Agent.update(__MODULE__, &Map.delete(&1, key)) && :ok
    def send_object(conn, _key, _content_type), do: conn
    def dump, do: Agent.get(__MODULE__, & &1)

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

  # Minimal PNG header declaring the given square dimensions.
  defp png(size), do: <<137, 80, 78, 71, 13, 10, 26, 10, 13::32, "IHDR", size::32, size::32, 0::64>>

  # A small valid CBR MPEG-1 Layer III stream (128 kbps, 44.1 kHz) so ingestion can parse a duration.
  defp mp3_bytes(frames) do
    frame_len = trunc(144 * 128 * 1000 / 44_100)
    frame = <<0xFF, 0xFB, 0x90, 0x00>> <> :binary.copy(<<0>>, frame_len - 4)
    :binary.copy(frame, frames)
  end

  describe "upload_episode/3" do
    test "stores audio, creates the episode, and ingests it to :ready", %{show: show} do
      audio = mp3_bytes(50)
      {:ok, episode} = Podcasts.upload_episode(show, %{"title" => "Ep 1", "description" => "notes"}, audio)

      assert episode.show_id == show.id
      assert episode.guid
      assert episode.audio_key == Storage.audio_key(show.id, episode.guid)
      assert {:ok, ^audio} = Storage.fetch(episode.audio_key)

      # Oban runs inline in test, so ingestion has already run synchronously.
      ready = Episode.get(episode.id)
      assert ready.status == :ready
      assert ready.duration_seconds > 0
      assert ready.audio_byte_size == byte_size(audio)
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

  describe "upload_episode/3 — failure" do
    test "does not store audio when metadata is invalid (no orphan object)", %{show: show} do
      assert {:error, %Ecto.Changeset{}} = Podcasts.upload_episode(show, %{"title" => ""}, "AUDIO")
      assert MapStore.dump() == %{}
    end
  end

  describe "user_storage_keys/1 and purge_keys/1" do
    test "collects a user's audio + cover keys and purges them", %{user: user, show: show} do
      {:ok, _} = Podcasts.upload_cover(show, ".png", png(1400))
      {:ok, episode} = Podcasts.upload_episode(show, %{"title" => "Ep"}, "AUDIO")

      keys = Podcasts.user_storage_keys(user)
      assert episode.audio_key in keys
      assert Storage.cover_key(show.id, "png") in keys

      :ok = Podcasts.purge_keys(keys)
      assert {:error, _} = Storage.fetch(episode.audio_key)
    end
  end

  describe "upload_cover/3" do
    test "stores a valid square cover and saves its public URL on the show", %{show: show} do
      bytes = png(1400)
      {:ok, updated} = Podcasts.upload_cover(show, ".png", bytes)

      assert updated.cover_key == Storage.cover_key(show.id, "png")
      assert {:ok, ^bytes} = Storage.fetch(Storage.cover_key(show.id, "png"))
    end

    test "rejects a cover smaller than 1400×1400", %{show: show} do
      assert {:error, :cover_too_small} = Podcasts.upload_cover(show, ".png", png(800))
    end

    test "rejects a non-square cover", %{show: show} do
      non_square = <<137, 80, 78, 71, 13, 10, 26, 10, 13::32, "IHDR", 1400::32, 1500::32, 0::64>>
      assert {:error, :cover_not_square} = Podcasts.upload_cover(show, ".png", non_square)
    end
  end

  describe "download_count/1" do
    test "counts PodcastEpisodeDownloaded events for the episode", %{show: show} do
      episode = episode_fixture(show)
      assert Podcasts.download_count(episode) == 0

      Store.append(%PodcastEpisodeDownloaded{id: episode.id, source: :feed}, stream: "podcast_download")
      Store.append(%PodcastEpisodeDownloaded{id: episode.id, source: :web}, stream: "podcast_download")

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
