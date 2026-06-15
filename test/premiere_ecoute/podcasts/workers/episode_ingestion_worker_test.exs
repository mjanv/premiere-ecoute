defmodule PremiereEcoute.Podcasts.Workers.EpisodeIngestionWorkerTest do
  use PremiereEcoute.DataCase, async: false

  import Bitwise

  alias PremiereEcoute.Podcasts.Episode
  alias PremiereEcoute.Podcasts.Storage
  alias PremiereEcoute.Podcasts.Workers.EpisodeIngestionWorker

  # Storage adapter stub: returns whatever bytes the test stashed under :stub_audio.
  defmodule StorageStub do
    @behaviour PremiereEcoute.Podcasts.Storage

    @impl true
    def fetch(_key), do: Application.get_env(:premiere_ecoute, :stub_audio, {:error, :missing})

    @impl true
    def put(_key, _bytes), do: :ok

    @impl true
    def delete(_key), do: :ok

    @impl true
    def send_object(conn, _key, _content_type), do: conn
  end

  # Minimal constant-bitrate MPEG-1 Layer III audio (128 kbps, 44.1 kHz).
  defp mp3_bytes(frames) do
    frame_len = trunc(144 * 128 * 1000 / 44_100)
    header = <<0xFF, 0xFB, 9 <<< 4, 0>>
    frame = header <> :binary.copy(<<0>>, frame_len - 4)
    :binary.copy(frame, frames)
  end

  setup do
    Application.put_env(:premiere_ecoute, Storage, adapter: StorageStub)

    on_exit(fn ->
      Application.delete_env(:premiere_ecoute, Storage)
      Application.delete_env(:premiere_ecoute, :stub_audio)
    end)

    user = user_fixture()
    show = show_fixture(user)

    episode =
      episode_fixture(show, %{
        status: :processing,
        audio_key: "podcasts/#{show.id}/episodes/key.mp3",
        duration_seconds: nil,
        audio_byte_size: nil,
        published_at: nil
      })

    %{episode: episode}
  end

  describe "run/1 success" do
    test "marks the episode ready with extracted duration and byte size", %{episode: episode} do
      audio = mp3_bytes(300)
      Application.put_env(:premiere_ecoute, :stub_audio, {:ok, audio})

      assert :ok = EpisodeIngestionWorker.run(episode)

      ready = Episode.get(episode.id)
      assert ready.status == :ready
      assert ready.audio_byte_size == byte_size(audio)
      assert ready.duration_seconds == round(byte_size(audio) * 8 / 128_000)
    end

    test "broadcasts an update so the studio dashboard can refresh", %{episode: episode} do
      Application.put_env(:premiere_ecoute, :stub_audio, {:ok, mp3_bytes(300)})
      PremiereEcoute.PubSub.subscribe(EpisodeIngestionWorker.topic(episode.show_id))

      assert :ok = EpisodeIngestionWorker.run(episode)
      assert_receive {:episode_updated, episode_id}
      assert episode_id == episode.id
    end
  end

  describe "run/1 failure" do
    test "marks the episode failed when the audio is not an MP3", %{episode: episode} do
      Application.put_env(:premiere_ecoute, :stub_audio, {:ok, :binary.copy(<<0>>, 500)})

      assert {:error, _} = EpisodeIngestionWorker.run(episode)
      assert Episode.get(episode.id).status == :failed
    end

    test "marks the episode failed when storage cannot fetch the object", %{episode: episode} do
      Application.put_env(:premiere_ecoute, :stub_audio, {:error, :not_found})

      assert {:error, :not_found} = EpisodeIngestionWorker.run(episode)
      assert Episode.get(episode.id).status == :failed
    end

    test "returns :not_found for a missing episode" do
      assert {:error, :not_found} = EpisodeIngestionWorker.run(nil)
    end
  end
end
