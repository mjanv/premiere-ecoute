defmodule PremiereEcoute.Accounts.User.OauthTokenTest do
  use PremiereEcoute.DataCase, async: true

  alias Ecto.Adapters.SQL.Sandbox
  alias PremiereEcoute.Accounts.Services.TokenRenewal
  alias PremiereEcoute.Accounts.User
  alias PremiereEcoute.Accounts.User.OauthToken

  @twitch_token %{
    user_id: "twitch_user_id",
    username: "twitch_username",
    access_token: "twitch_access_token",
    refresh_token: "twitch_refresh_token",
    expires_in: 3600
  }

  @spotify_token %{
    user_id: "spotify_user_id",
    username: "spotify_username",
    access_token: "spotify_access_token",
    refresh_token: "spotify_refresh_token",
    expires_in: 3600
  }

  setup do
    %{user: user_fixture()}
  end

  describe "create/1" do
    test "can create oauth tokens for an user", %{user: user} do
      {:ok, user} = OauthToken.create(user, :twitch, @twitch_token)
      {:ok, user} = OauthToken.create(user, :spotify, @spotify_token)

      assert %OauthToken{
               provider: :twitch,
               user_id: "twitch_user_id",
               username: "twitch_username",
               access_token: "twitch_access_token",
               refresh_token: "twitch_refresh_token",
               expires_at: _
             } = user.twitch

      assert %OauthToken{
               provider: :spotify,
               user_id: "spotify_user_id",
               username: "spotify_username",
               access_token: "spotify_access_token",
               refresh_token: "spotify_refresh_token",
               expires_at: _
             } = user.spotify
    end

    test "can recreate oauth tokens for an user", %{user: user} do
      {:ok, user} = OauthToken.create(user, :twitch, @twitch_token)
      {:ok, user} = OauthToken.create(user, :twitch, @twitch_token)
      {:ok, user} = OauthToken.create(user, :spotify, @spotify_token)

      assert %OauthToken{
               provider: :twitch,
               user_id: "twitch_user_id",
               username: "twitch_username",
               access_token: "twitch_access_token",
               refresh_token: "twitch_refresh_token",
               expires_at: _
             } = user.twitch

      assert %OauthToken{
               provider: :spotify,
               user_id: "spotify_user_id",
               username: "spotify_username",
               access_token: "spotify_access_token",
               refresh_token: "spotify_refresh_token",
               expires_at: _
             } = user.spotify
    end
  end

  describe "refresh/1" do
    test "can refresh existing oauth tokens for an user", %{user: user} do
      {:ok, user} = OauthToken.create(user, :twitch, @twitch_token)
      {:ok, user} = OauthToken.create(user, :spotify, @spotify_token)

      attrs = %{access_token: "new_twitch_access_token", refresh_token: "new_twitch_refresh_token", expires_in: 3600}
      {:ok, user} = OauthToken.refresh(user, :twitch, attrs)

      attrs = %{access_token: "new_spotify_access_token", refresh_token: "new_spotify_refresh_token", expires_in: 3600}
      {:ok, user} = OauthToken.refresh(user, :spotify, attrs)

      assert %OauthToken{
               provider: :twitch,
               user_id: "twitch_user_id",
               username: "twitch_username",
               access_token: "new_twitch_access_token",
               refresh_token: "new_twitch_refresh_token",
               expires_at: _
             } = user.twitch

      assert %OauthToken{
               provider: :spotify,
               user_id: "spotify_user_id",
               username: "spotify_username",
               access_token: "new_spotify_access_token",
               refresh_token: "new_spotify_refresh_token",
               expires_at: _
             } = user.spotify
    end

    test "cannot refresh non-existing oauth tokens for an user", %{user: user} do
      {:ok, user} = OauthToken.create(user, :twitch, @twitch_token)

      attrs = %{access_token: "new_twitch_access_token", refresh_token: "new_twitch_refresh_token", expires_in: 3600}
      {:ok, user} = OauthToken.refresh(user, :twitch, attrs)

      attrs = %{access_token: "new_spotify_access_token", refresh_token: "new_spotify_refresh_token", expires_in: 3600}

      assert {:error, %User{}} = OauthToken.refresh(user, :spotify, attrs)
    end
  end

  describe "disconnect/1" do
    test "can delete oauth tokens for an user", %{user: user} do
      {:ok, user} = OauthToken.create(user, :twitch, @twitch_token)
      {:ok, user} = OauthToken.create(user, :spotify, @spotify_token)

      {:ok, user} = OauthToken.disconnect(user, :twitch)
      {:ok, user} = OauthToken.disconnect(user, :spotify)

      assert user.twitch == nil
      assert user.spotify == nil
    end

    test "can delete non-existing oauth tokens for an user", %{user: user} do
      {:ok, user} = OauthToken.create(user, :twitch, @twitch_token)

      {:ok, user} = OauthToken.disconnect(user, :twitch)
      {:ok, user} = OauthToken.disconnect(user, :spotify)

      assert user.twitch == nil
      assert user.spotify == nil
    end
  end

  describe "delete_all_tokens/1" do
    test "delete all oauth tokens for an user", %{user: user} do
      {:ok, user} = OauthToken.create(user, :twitch, @twitch_token)
      {:ok, user} = OauthToken.create(user, :spotify, @spotify_token)

      {:ok, user} = OauthToken.delete_all_tokens(user)

      assert user.twitch == nil
      assert user.spotify == nil
    end
  end

  describe "refresh_locked/4" do
    defp always_expired(_expires_at), do: true
    defp never_expired(_expires_at), do: false

    test "refreshes when the locked row is expired", %{user: user} do
      {:ok, user} = OauthToken.create(user, :spotify, @spotify_token)

      renew_fun = fn "spotify_refresh_token" ->
        {:ok, %{access_token: "new_access_token", refresh_token: "new_refresh_token", expires_in: 3600}}
      end

      assert {:ok, user} = OauthToken.refresh_locked(user, :spotify, &always_expired/1, renew_fun)
      assert %OauthToken{access_token: "new_access_token", refresh_token: "new_refresh_token"} = user.spotify
    end

    test "skips renew_fun entirely when the locked row is not expired", %{user: user} do
      {:ok, user} = OauthToken.create(user, :spotify, @spotify_token)

      renew_fun = fn _refresh_token -> flunk("renew_fun should not be called when the row is fresh") end

      assert {:ok, user} = OauthToken.refresh_locked(user, :spotify, &never_expired/1, renew_fun)
      assert %OauthToken{access_token: "spotify_access_token"} = user.spotify
    end

    test "returns {:error, nil} when no token row exists", %{user: user} do
      renew_fun = fn _refresh_token -> flunk("renew_fun should not be called when there is no row") end

      assert {:error, nil} = OauthToken.refresh_locked(user, :spotify, &always_expired/1, renew_fun)
    end

    test "disconnects the provider on invalid_grant when genuinely expired", %{user: user} do
      {:ok, user} = OauthToken.create(user, :spotify, @spotify_token)

      renew_fun = fn _refresh_token -> {:error, :invalid_grant} end

      assert {:ok, user} = OauthToken.refresh_locked(user, :spotify, &always_expired/1, renew_fun)
      assert user.spotify == nil
    end

    test "a generic provider error leaves the token untouched", %{user: user} do
      {:ok, user} = OauthToken.create(user, :spotify, @spotify_token)

      renew_fun = fn _refresh_token -> {:error, "network error"} end

      assert {:error, "network error"} = OauthToken.refresh_locked(user, :spotify, &always_expired/1, renew_fun)

      user = User.preload(user)
      assert %OauthToken{access_token: "spotify_access_token"} = user.spotify
    end

    test "a concurrent second caller is rescued by the first caller's refresh and never calls the provider", %{user: user} do
      {:ok, user} = OauthToken.create(user, :spotify, %{@spotify_token | expires_in: -3600})

      {:ok, counter} = Agent.start_link(fn -> 0 end)

      renew_fun = fn "spotify_refresh_token" ->
        Agent.update(counter, &(&1 + 1))
        # Hold the row lock open briefly so the second caller is forced to block
        # on `SELECT ... FOR UPDATE` instead of racing this transaction.
        Process.sleep(200)
        {:ok, %{access_token: "new_access_token", refresh_token: "new_refresh_token", expires_in: 3600}}
      end

      # Use the real expiry predicate (not always_expired/1): the second caller
      # must re-check the locked row's actual expires_at, which the first
      # caller will have already bumped into the future by the time the lock
      # is released — that re-check is exactly what should skip renew_fun.
      expired_fun = &TokenRenewal.token_expired?/1

      test_pid = self()

      task =
        Task.async(fn ->
          Sandbox.allow(PremiereEcoute.Repo, test_pid, self())
          OauthToken.refresh_locked(user, :spotify, expired_fun, renew_fun)
        end)

      # Give the task a head start so it acquires the row lock first.
      Process.sleep(50)

      assert {:ok, second_result} = OauthToken.refresh_locked(user, :spotify, expired_fun, renew_fun)
      assert {:ok, first_result} = Task.await(task, 5_000)

      assert Agent.get(counter, & &1) == 1
      assert first_result.spotify.access_token == "new_access_token"
      assert second_result.spotify.access_token == "new_access_token"
    end
  end
end
