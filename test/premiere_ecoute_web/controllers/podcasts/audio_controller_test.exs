defmodule PremiereEcouteWeb.Podcasts.AudioControllerTest do
  use PremiereEcouteWeb.ConnCase, async: false

  alias PremiereEcoute.Events.EpisodeDownloaded
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Podcasts.Storage

  setup do
    Application.put_env(:premiere_ecoute, Storage, public_base_url: "https://cdn.test")
    on_exit(fn -> Application.delete_env(:premiere_ecoute, Storage) end)

    user = user_fixture(%{username: "audiostreamer"})
    show = show_fixture(user, %{title: "Audio Show", published: true})
    episode = episode_fixture(show, %{audio_key: "podcasts/#{show.id}/episodes/key.mp3"})
    %{show: show, episode: episode}
  end

  describe "GET episode audio" do
    test "redirects to the public storage URL", %{conn: conn, show: show, episode: episode} do
      conn = get(conn, ~p"/podcasts/audiostreamer/#{show.slug}/episodes/#{episode.guid}/audio")

      assert redirected_to(conn, 302) == "https://cdn.test/#{episode.audio_key}"
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
  end
end
