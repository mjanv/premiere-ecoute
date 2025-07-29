defmodule PremiereEcoute.Accounts.User.FollowTest do
  use PremiereEcoute.DataCase

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Follow

  alias PremiereEcoute.EventStore

  describe "follow/3" do
    test "add a streamer to any role follow list" do
      for role <- [:viewer, :streamer, :admin, :bot] do
        %{id: user_id} = user = user_fixture(%{role: role})
        %{id: streamer_id} = streamer = user_fixture(%{role: :streamer})

        {:ok, follow} = Accounts.follow(user, streamer)

        assert %Follow{user_id: ^user_id, streamer_id: ^streamer_id, followed_at: nil} = follow
        assert EventStore.read("user-#{user_id}") == [%ChannelFollowed{id: user.id, streamer_id: streamer.id}]
      end
    end

    test "add a followed_at date to the follow" do
      for role <- [:viewer, :streamer, :admin, :bot] do
        %{id: user_id} = user = user_fixture(%{role: role})
        %{id: streamer_id} = streamer = user_fixture(%{role: :streamer})

        {:ok, follow} = Accounts.follow(user, streamer, %{followed_at: ~N[2020-07-18 07:59:47]})

        assert %Follow{user_id: ^user_id, streamer_id: ^streamer_id, followed_at: ~N[2020-07-18 07:59:47]} = follow
        assert EventStore.read("user-#{user_id}") == [%ChannelFollowed{id: user.id, streamer_id: streamer.id}]
      end
    end

    test "cannot add any role to a viewer follow list" do
      for role <- [:viewer, :streamer, :admin, :bot] do
        user = user_fixture(%{role: role})
        viewer = user_fixture(%{role: :viewer})

        {:error, changeset} = Accounts.follow(user, viewer)

        assert Repo.traverse_errors(changeset) == %{streamer: ["must have the streamer role"]}
      end
    end

    test "update the list of channels attached to a viewer" do
      %{id: user_id} = user = user_fixture(%{role: :viewer})

      {:ok, _} = Accounts.follow(user, user_fixture(%{role: :streamer}))
      {:ok, _} = Accounts.follow(user, user_fixture(%{role: :streamer}))
      {:ok, _} = Accounts.follow(user, user_fixture(%{role: :streamer}))
      {:ok, _} = Accounts.follow(user, user_fixture(%{role: :streamer}))

      user = User.get(user_id)

      assert [
               %User{role: :streamer},
               %User{role: :streamer},
               %User{role: :streamer},
               %User{role: :streamer}
             ] = user.channels
    end
  end

  describe "unfollow/2" do
    test "unfollow a streamer from a viewer follow list" do
      %{id: user_id} = user = user_fixture(%{role: :viewer})
      %{id: streamer_id} = streamer = user_fixture(%{role: :streamer})
      {:ok, follow} = Accounts.follow(user, streamer)

      {:ok, unfollow} = Accounts.unfollow(user, streamer)

      assert %Follow{user_id: ^user_id, streamer_id: ^streamer_id} = follow
      assert %Follow{user_id: ^user_id, streamer_id: ^streamer_id} = unfollow

      assert EventStore.read("user-#{user_id}") == [
               %ChannelFollowed{id: user.id, streamer_id: streamer.id},
               %ChannelUnfollowed{id: user.id, streamer_id: streamer.id}
             ]
    end

    test "cannot unfollow a streamer not part of a viewer follow list" do
      viewer = user_fixture(%{role: :viewer})
      streamer = user_fixture(%{role: :streamer})

      {:error, changeset} = Accounts.unfollow(viewer, streamer)

      assert Repo.traverse_errors(changeset) == %{streamer: ["You are not following this streamer"]}
    end

    test "update the list of channels attached to a viewer" do
      %{id: user_id} = user = user_fixture(%{role: :viewer})

      {:ok, _} = Accounts.follow(user, user_fixture(%{role: :streamer}))
      {:ok, _} = Accounts.follow(user, user_fixture(%{role: :streamer}))
      {:ok, _} = Accounts.follow(user, user_fixture(%{role: :streamer}))

      streamer = user_fixture(%{role: :streamer})
      {:ok, _} = Accounts.follow(user, streamer)
      {:ok, _} = Accounts.unfollow(user, streamer)

      user = User.get(user_id)

      assert [
               %User{role: :streamer},
               %User{role: :streamer},
               %User{role: :streamer}
             ] = user.channels
    end
  end

  describe "discover_follows/1" do
    test "returns the list of non-followed streamers by a viewer" do
      user = user_fixture(%{role: :viewer})

      follows = for _ <- 1..5, do: user_fixture(%{role: :streamer})
      nonfollows = for _ <- 1..3, do: user_fixture(%{role: :streamer})

      Enum.each(follows, fn f -> Accounts.follow(user, f) end)

      discovers = Accounts.discover_follows(user)

      assert discovers == nonfollows
    end

    test "returns an empty list when no streamers are defined" do
      user = user_fixture(%{role: :viewer})

      assert Accounts.discover_follows(user) == []
    end
  end
end
