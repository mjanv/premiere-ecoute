defmodule PremiereEcoute.Podcasts.StatisticsTest do
  use PremiereEcoute.DataCase, async: false

  alias PremiereEcoute.Events.EpisodeDownloaded
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Podcasts

  setup do
    %{show: show_fixture(user_fixture())}
  end

  defp download(episode, source) do
    Store.append(%EpisodeDownloaded{id: episode.id, source: source}, stream: "podcast_download")
  end

  describe "show_download_stats/1" do
    test "totals downloads across episodes, split by source", %{show: show} do
      e1 = episode_fixture(show)
      e2 = episode_fixture(show)
      download(e1, :feed)
      download(e1, :feed)
      download(e1, :web)
      download(e2, :feed)

      assert %{total: 4, feed: 3, web: 1} = Podcasts.show_download_stats(show)
    end

    test "is zero when there are no downloads", %{show: show} do
      episode_fixture(show)
      assert %{total: 0, feed: 0, web: 0} = Podcasts.show_download_stats(show)
    end
  end

  describe "episode_download_stats/1" do
    test "scopes counts to a single episode", %{show: show} do
      e1 = episode_fixture(show)
      e2 = episode_fixture(show)
      download(e1, :web)
      download(e2, :feed)

      assert %{total: 1, web: 1, feed: 0} = Podcasts.episode_download_stats(e1)
    end
  end

  describe "show_downloads_last/2" do
    test "counts downloads within the recent window", %{show: show} do
      e = episode_fixture(show)
      download(e, :feed)
      download(e, :web)

      assert Podcasts.show_downloads_last(show, 30) == 2
    end
  end

  describe "episode_downloads_over_time/3" do
    test "returns time-bucketed rows", %{show: show} do
      e = episode_fixture(show)
      download(e, :feed)

      rows = Podcasts.episode_downloads_over_time(e, :day)
      assert Enum.sum(Enum.map(rows, & &1.count)) == 1
    end
  end
end
