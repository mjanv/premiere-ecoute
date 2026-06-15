defmodule PremiereEcoute.Podcasts.ShowTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Events.PodcastShowPublished
  alias PremiereEcoute.Events.Store
  alias PremiereEcoute.Podcasts.Show

  describe "changeset/2" do
    test "valid with required fields" do
      user = user_fixture()
      attrs = %{user_id: user.id, title: "My Show", language: "en"}

      assert %{valid?: true} = Show.changeset(%Show{}, attrs)
    end

    test "invalid without title or user" do
      changeset = Show.changeset(%Show{}, %{})

      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "rejects an invalid Apple category" do
      user = user_fixture()
      changeset = Show.changeset(%Show{}, %{user_id: user.id, title: "X", category: "Nonsense"})

      assert "is not a valid Apple Podcasts category" in errors_on(changeset).category
    end

    test "generates a slug from the title" do
      user = user_fixture()
      {:ok, show} = Show.create(%{user_id: user.id, title: "Hello World Show"})

      assert show.slug == "hello-world-show"
    end
  end

  describe "create/1" do
    test "persists a show" do
      user = user_fixture()

      {:ok, show} = Show.create(%{user_id: user.id, title: "Pod"})

      assert show.id
      assert show.user_id == user.id
    end

    test "enforces unique slug per user" do
      user = user_fixture()
      {:ok, _} = Show.create(%{user_id: user.id, title: "Same Title"})

      assert {:error, changeset} = Show.create(%{user_id: user.id, title: "Same Title"})
      assert %{slug: _} = errors_on(changeset)
    end
  end

  describe "publish/1" do
    test "marks published and emits PodcastShowPublished" do
      user = user_fixture()
      {:ok, show} = Show.create(%{user_id: user.id, title: "Pod"})

      refute show.published
      {:ok, published} = Show.publish(show)

      assert published.published
      assert %PodcastShowPublished{id: show_id} = Store.last("podcasts_show-#{show.id}")
      assert show_id == show.id
    end
  end

  describe "all_for_user/1" do
    test "returns only the user's shows" do
      user = user_fixture()
      other = user_fixture()
      show_fixture(user, %{title: "A"})
      show_fixture(user, %{title: "B"})
      show_fixture(other, %{title: "C"})

      assert length(Show.all_for_user(user)) == 2
    end
  end

  describe "published_by_users/1" do
    test "groups only published shows by owner id" do
      published = user_fixture()
      draft_only = user_fixture()
      none = user_fixture()

      a = show_fixture(published, %{title: "A", published: true})
      b = show_fixture(published, %{title: "B", published: true})
      show_fixture(published, %{published: false})
      show_fixture(draft_only, %{published: false})

      result = Show.published_by_users([published.id, draft_only.id, none.id])

      assert MapSet.new(Enum.map(result[published.id], & &1.id)) == MapSet.new([a.id, b.id])
      refute Map.has_key?(result, draft_only.id)
      refute Map.has_key?(result, none.id)
    end
  end

  describe "get_published/2" do
    test "returns a published show by username and slug" do
      user = user_fixture(%{username: "streamer1"})
      show = show_fixture(user, %{title: "Live Pod", published: true})

      assert %Show{id: id} = Show.get_published("streamer1", show.slug)
      assert id == show.id
    end

    test "does not return an unpublished show" do
      user = user_fixture(%{username: "streamer2"})
      show = show_fixture(user, %{title: "Draft Pod", published: false})

      assert is_nil(Show.get_published("streamer2", show.slug))
    end
  end
end
