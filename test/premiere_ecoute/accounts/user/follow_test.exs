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
    test "returns the list of non-followed streamers by a viewer" do
      user = user_fixture(%{role: :viewer})

      follows = for _ <- 1..5, do: user_fixture(%{role: :streamer})
      nonfollows = for _ <- 1..3, do: user_fixture(%{role: :streamer})

      Enum.each(follows, fn f -> Accounts.follow(user, f) end)

      discovers = Accounts.discover_follows(user)
      nonfollows_ids = Enum.map(nonfollows, & &1.id)

      # Verify our non-followed users are in the discovers list
      assert Enum.all?(nonfollows_ids, fn id -> Enum.any?(discovers, fn u -> u.id == id end) end)
      # Verify our followed users are NOT in the discovers list
      followed_ids = Enum.map(follows, & &1.id)
      refute Enum.any?(discovers, fn u -> u.id in followed_ids end)
    end

    test "returns users that the viewer is not following" do
      user = user_fixture(%{role: :viewer})
      followed = user_fixture(%{role: :streamer})

      Accounts.follow(user, followed)

      discovers = Accounts.discover_follows(user)

      # The followed user should not be in discovers
      refute Enum.any?(discovers, fn u -> u.id == followed.id end)
      # The user themselves should not be in discovers
      refute Enum.any?(discovers, fn u -> u.id == user.id end)
    end
  end
end
