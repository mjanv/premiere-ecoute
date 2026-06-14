defmodule PremiereEcouteWeb.Podcasts.AudioControllerTest do
  use PremiereEcouteWeb.ConnCase, async: false

  alias PremiereEcoute.Events.EpisodeDownloaded
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Podcasts.Storage

  # Stub adapter so the controller's streaming + tracking can be asserted without a real backend.
  defmodule AudioStub do
    @behaviour PremiereEcoute.Podcasts.Storage

    import Plug.Conn

    @impl true
    def fetch(_key), do: {:error, :not_supported}
    @impl true
    def put(_key, _bytes), do: :ok
    @impl true
    def delete(_key), do: :ok

    @impl true
    def send_object(conn, key, content_type) do
      conn
      |> put_resp_header("content-type", content_type)
      |> put_resp_header("accept-ranges", "bytes")
      |> send_resp(200, "AUDIO:" <> key)
    end
  end

  setup do
    Application.put_env(:premiere_ecoute, Storage, adapter: AudioStub)
    on_exit(fn -> Application.delete_env(:premiere_ecoute, Storage) end)

    user = user_fixture(%{username: "audiostreamer"})
    show = show_fixture(user, %{title: "Audio Show", published: true})
    episode = episode_fixture(show, %{audio_key: "podcasts/#{show.id}/episodes/key.mp3"})
    %{show: show, episode: episode}
  end

  describe "GET episode audio" do
    test "streams the audio bytes through the app with Range support advertised", %{conn: conn, show: show, episode: episode} do
      conn = get(conn, ~p"/podcasts/audiostreamer/#{show.slug}/episodes/#{episode.guid}/audio")

      assert response(conn, 200) == "AUDIO:#{episode.audio_key}"
      assert get_resp_header(conn, "accept-ranges") == ["bytes"]
      assert get_resp_header(conn, "content-type") == ["audio/mpeg"]
    end

    test "records an EpisodeDownloaded event tagged :feed by default", %{conn: conn, show: show, episode: episode} do
      get(conn, ~p"/podcasts/audiostreamer/#{show.slug}/episodes/#{episode.guid}/audio")

      assert %EpisodeDownloaded{id: id, source: :feed} = Store.last("podcast_download-#{episode.id}")
      assert id == episode.id
    end

    test "tags website plays as :web", %{conn: conn, show: show, episode: episode} do
      get(conn, ~p"/podcasts/audiostreamer/#{show.slug}/episodes/#{episode.guid}/audio?source=web")

      assert %EpisodeDownloaded{source: :web} = Store.last("podcast_download-#{episode.id}")
    end

    test "returns 404 for an unknown episode", %{conn: conn, show: show} do
      conn = get(conn, ~p"/podcasts/audiostreamer/#{show.slug}/episodes/missing-guid/audio")
      assert response(conn, 404)
    end

    test "HEAD returns headers (size, ranges) without a body or a download count", %{conn: conn, show: show, episode: episode} do
      path = ~p"/podcasts/audiostreamer/#{show.slug}/episodes/#{episode.guid}/audio"
      conn = dispatch(conn, @endpoint, "head", path)

      assert conn.status == 200
      assert conn.resp_body == ""
      assert get_resp_header(conn, "accept-ranges") == ["bytes"]
      assert get_resp_header(conn, "content-length") == ["#{episode.audio_byte_size}"]
      assert Store.read("podcast_download-#{episode.id}", :event) == []
    end
  end
end
