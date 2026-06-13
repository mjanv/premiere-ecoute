defmodule PremiereEcoute.Podcasts.EpisodeTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Events.EpisodePublished
  alias PremiereEcoute.Events.EpisodeUploaded
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Podcasts.Episode

  setup do
    user = user_fixture()
    %{show: show_fixture(user)}
  end

  describe "changeset/2" do
    test "valid with required fields", %{show: show} do
      attrs = %{show_id: show.id, title: "Ep 1"}
      assert %{valid?: true} = Episode.changeset(%Episode{}, attrs)
    end

    test "auto-generates a permanent GUID when absent", %{show: show} do
      changeset = Episode.changeset(%Episode{}, %{show_id: show.id, title: "Ep"})
      assert get_change(changeset, :guid)
    end

    test "keeps a provided GUID", %{show: show} do
      changeset = Episode.changeset(%Episode{}, %{show_id: show.id, title: "Ep", guid: "fixed-guid"})
      assert get_field(changeset, :guid) == "fixed-guid"
    end

    test "invalid without title or show", %{show: _show} do
      changeset = Episode.changeset(%Episode{}, %{})
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).show_id
    end
  end

  describe "create/1" do
    test "persists with default :uploading status and emits EpisodeUploaded", %{show: show} do
      {:ok, episode} = Episode.create(%{show_id: show.id, title: "Ep"})

      assert episode.status == :uploading
      assert %EpisodeUploaded{id: id, show_id: show_id} = Store.last("podcasts_episode-#{episode.id}")
      assert id == episode.id
      assert show_id == show.id
    end
  end

  describe "publish/2" do
    test "publishes a ready episode and emits EpisodePublished", %{show: show} do
      episode = episode_fixture(show, %{status: :ready, published_at: nil})

      {:ok, published} = Episode.publish(episode)

      assert published.published_at
      assert %EpisodePublished{id: id} = Store.last("podcasts_episode-#{episode.id}")
      assert id == episode.id
    end

    test "refuses to publish a non-ready episode", %{show: show} do
      episode = episode_fixture(show, %{status: :processing, published_at: nil})

      assert {:error, :not_ready} = Episode.publish(episode)
    end

    test "schedules a future publication that stays out of the feed until due", %{show: show} do
      episode = episode_fixture(show, %{status: :ready, published_at: nil})
      future = DateTime.add(DateTime.utc_now(), 7, :day)

      {:ok, published} = Episode.publish(episode, future)

      assert DateTime.compare(published.published_at, DateTime.utc_now()) == :gt
      refute Enum.any?(Episode.feed_episodes(show), &(&1.id == episode.id))
    end
  end

  describe "feed_episodes/1" do
    test "returns only ready, published episodes, newest first", %{show: show} do
      old = episode_fixture(show, %{title: "Old", published_at: ~U[2026-01-01 00:00:00Z]})
      new = episode_fixture(show, %{title: "New", published_at: ~U[2026-06-01 00:00:00Z]})
      _draft = episode_fixture(show, %{title: "Draft", status: :processing, published_at: nil})
      _future = episode_fixture(show, %{title: "Future", published_at: ~U[2099-01-01 00:00:00Z]})
      _unpublished = episode_fixture(show, %{title: "Ready but unpublished", published_at: nil})

      titles = show |> Episode.feed_episodes() |> Enum.map(& &1.title)

      assert titles == [new.title, old.title]
    end
  end

  describe "mark_ready/2 and mark_failed/1" do
    test "mark_ready stores metadata and flips status", %{show: show} do
      episode = episode_fixture(show, %{status: :processing, published_at: nil})

      {:ok, ready} = Episode.mark_ready(episode, %{duration_seconds: 1234, audio_byte_size: 999})

      assert ready.status == :ready
      assert ready.duration_seconds == 1234
      assert ready.audio_byte_size == 999
    end

    test "mark_failed flips status to failed", %{show: show} do
      episode = episode_fixture(show, %{status: :processing, published_at: nil})
      {:ok, failed} = Episode.mark_failed(episode)
      assert failed.status == :failed
    end
  end
end
