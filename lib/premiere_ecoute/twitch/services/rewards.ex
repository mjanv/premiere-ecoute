defmodule PremiereEcoute.Twitch.Services.Rewards do
  @moduledoc """
  Manages Twitch channel point custom rewards lifecycle.

  Failed operations are logged and skipped rather than aborting.
  """

  require Logger

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Twitch.Reward

  @doc """
  Creates rewards from a list of reward structs. Returns the list of successfully created rewards.
  """
  @spec create_rewards(any(), list(Reward.t())) :: list(Reward.t())
  def create_rewards(scope, rewards) do
    Enum.flat_map(rewards, fn %Reward{} = reward ->
      reward
      |> Map.take([:title, :cost, :prompt, :is_user_input_required])
      |> Map.reject(fn {_k, v} -> is_nil(v) end)
      |> then(fn attrs -> Apis.twitch().create_reward(scope, attrs) end)
      |> case do
        {:ok, reward} ->
          Logger.info("Created reward #{reward.title}")
          [reward]

        {:error, reason} ->
          Logger.warning("Failed to create reward: #{inspect(reason)}")
          []
      end
    end)
  end

  @doc """
  Deletes all given rewards. Returns `:ok` regardless of individual failures.
  """
  @spec delete_rewards(any(), list(Reward.t())) :: :ok
  def delete_rewards(scope, rewards) do
    Enum.each(rewards, fn reward ->
      case Apis.twitch().delete_reward(scope, reward.id) do
        :ok -> Logger.info("Deleted reward #{reward.id} (#{reward.title})")
        {:error, reason} -> Logger.warning("Failed to delete reward #{reward.id}: #{inspect(reason)}")
      end
    end)
  end
end
