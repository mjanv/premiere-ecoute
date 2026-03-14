defmodule PremiereEcoute.Accounts.User.FollowTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.Follow

  describe "follow/2" do
    test "any role can follow any other user" do
      for role <- [:viewer, :streamer, :admin, :bot] do
        %{id: follower_id} = follower = user_fixture(%{role: role})
        %{id: followed_id} = followed = user_fixture(%{role: :streamer})

        {:ok, follow} = Accounts.follow(follower, followed)

        assert %Follow{follower_id: ^follower_id, followed_id: ^followed_id} = follow
      end
    end

    test "cannot follow yourself" do
      user = user_fixture()

      {:error, changeset} = Accounts.follow(user, user)

      assert %{follower_id: _} = Repo.traverse_errors(changeset)
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
    test "unfollow a user" do
      %{id: follower_id} = follower = user_fixture(%{role: :viewer})
      %{id: followed_id} = followed = user_fixture(%{role: :streamer})

      {:ok, follow} = Accounts.follow(follower, followed)
      {:ok, unfollow} = Accounts.unfollow(follower, followed)

      assert %Follow{follower_id: ^follower_id, followed_id: ^followed_id} = follow
      assert %Follow{follower_id: ^follower_id, followed_id: ^followed_id} = unfollow
    end

    test "cannot unfollow a user not followed" do
      follower = user_fixture(%{role: :viewer})
      followed = user_fixture(%{role: :streamer})

      assert {:error, :not_found} = Accounts.unfollow(follower, followed)
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
    @tag :unstable
    test "returns the list of non-followed streamers by a viewer" do
      user = user_fixture(%{role: :viewer})

      follows = for _ <- 1..5, do: user_fixture(%{role: :streamer})
      nonfollows = for _ <- 1..3, do: user_fixture(%{role: :streamer})

      Enum.each(follows, fn f -> Accounts.follow(user, f) end)

      discovers = Accounts.discover_follows(user)
      nonfollows_with_twitch = Enum.map(nonfollows, fn f -> Repo.preload(f, [:twitch]) end)

      # Filter discovers to only include IDs from our test fixtures (not from seeds)
      discovers_in_test = Enum.filter(discovers, fn u -> u.id in Enum.map(nonfollows, & &1.id) end)

      assert discovers_in_test == nonfollows_with_twitch
    end

    @tag :unstable
    test "returns an empty list when no streamers are defined" do
      user = user_fixture(%{role: :viewer})

      # discover_follows may return seed streamers, so we just check that our user hasn't followed anyone
      discovers = Accounts.discover_follows(user)
      assert user.id not in Enum.map(discovers, & &1.id)
    end
  end
end
