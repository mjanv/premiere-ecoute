defmodule PremiereEcoute.Twitch.Services.RewardsTest do
  use PremiereEcoute.DataCase, async: true

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.Streaming.TwitchApi.Mock, as: TwitchApi
  alias PremiereEcoute.Twitch.Reward
  alias PremiereEcoute.Twitch.Services.Rewards

  setup do
    user = user_fixture(%{twitch: %{user_id: "274637212"}})
    {:ok, %{scope: Scope.for_user(user)}}
  end

  describe "create_rewards/2" do
    test "returns an empty list without calling the API when given an empty list", %{scope: scope} do
      assert Rewards.create_rewards(scope, []) == []
    end

    test "creates each reward and returns the created structs", %{scope: scope} do
      expect(TwitchApi, :create_reward, fn _scope, %{title: "Song request", cost: 1_000, prompt: "Request a song"} ->
        {:ok, created_reward(id: "1", title: "Song request", cost: 1_000)}
      end)

      expect(TwitchApi, :create_reward, fn _scope, %{title: "Skip track", cost: 5_000} ->
        {:ok, created_reward(id: "2", title: "Skip track", cost: 5_000)}
      end)

      rewards = [
        %Reward{title: "Song request", cost: 1_000, prompt: "Request a song"},
        %Reward{title: "Skip track", cost: 5_000}
      ]

      assert [
               %Reward{id: "1", title: "Song request"},
               %Reward{id: "2", title: "Skip track"}
             ] = Rewards.create_rewards(scope, rewards)
    end

    test "drops nil fields from the create attrs sent to the API", %{scope: scope} do
      expect(TwitchApi, :create_reward, fn _scope, attrs ->
        refute Map.has_key?(attrs, :prompt)
        refute Map.has_key?(attrs, :id)
        refute Map.has_key?(attrs, :broadcaster_id)
        {:ok, created_reward(id: "1", title: "Song request", cost: 1_000)}
      end)

      Rewards.create_rewards(scope, [%Reward{title: "Song request", cost: 1_000}])
    end

    test "skips rewards that fail to create and keeps the ones that succeed", %{scope: scope} do
      expect(TwitchApi, :create_reward, fn _scope, %{title: "Good reward"} ->
        {:ok, created_reward(id: "1", title: "Good reward")}
      end)

      expect(TwitchApi, :create_reward, fn _scope, %{title: "Bad reward"} ->
        {:error, :bad_request}
      end)

      rewards = [
        %Reward{title: "Good reward", cost: 1_000},
        %Reward{title: "Bad reward", cost: 1_000}
      ]

      assert [%Reward{id: "1", title: "Good reward"}] = Rewards.create_rewards(scope, rewards)
    end
  end

  describe "delete_rewards/2" do
    test "returns :ok without calling the API when given an empty list", %{scope: scope} do
      assert Rewards.delete_rewards(scope, []) == :ok
    end

    test "deletes each reward and returns :ok", %{scope: scope} do
      expect(TwitchApi, :delete_reward, fn _scope, "1" -> :ok end)
      expect(TwitchApi, :delete_reward, fn _scope, "2" -> :ok end)

      rewards = [
        %Reward{id: "1", title: "Song request"},
        %Reward{id: "2", title: "Skip track"}
      ]

      assert Rewards.delete_rewards(scope, rewards) == :ok
    end

    test "returns :ok even when individual deletions fail", %{scope: scope} do
      expect(TwitchApi, :delete_reward, fn _scope, "1" -> {:error, :not_found} end)

      assert Rewards.delete_rewards(scope, [%Reward{id: "1", title: "Song request"}]) == :ok
    end
  end

  defp created_reward(attrs) do
    %Reward{
      id: attrs[:id],
      broadcaster_id: "274637212",
      title: attrs[:title],
      cost: attrs[:cost] || 1_000,
      prompt: "",
      is_enabled: true,
      is_paused: false,
      is_in_stock: true,
      is_user_input_required: false
    }
  end
end
