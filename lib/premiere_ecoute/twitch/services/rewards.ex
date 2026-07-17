defmodule PremiereEcoute.Twitch.Services.Rewards do
  @moduledoc """
  Manages Twitch channel point custom rewards lifecycle.

  Reward configs are string-keyed maps (as stored in session options JSON).
  Failed operations are logged and skipped rather than aborting.
  """

  require Logger

  alias PremiereEcoute.Apis
  alias PremiereEcoute.Twitch.Reward

  @doc """
  Creates rewards from a list of config maps. Returns the list of successfully created rewards.
  """
  @spec create_rewards(any(), list(map())) :: list(Reward.t())
  def create_rewards(_scope, []), do: []

  def create_rewards(scope, reward_configs) do
    Enum.flat_map(reward_configs, fn attrs ->
      # Keys come from session options JSON. Use to_existing_atom (the reward attr
      # names all exist as atoms in TwitchApi.Rewards.create_attrs) to avoid minting
      # atoms from persisted data. An unexpected key raises rather than growing the atom table.
      atom_keyed = Map.new(attrs, fn {k, v} -> {String.to_existing_atom(k), v} end)

      case Apis.twitch().create_reward(scope, atom_keyed) do
        {:ok, reward} ->
          Logger.info("Created reward #{reward.id} (#{reward.title})")
          [reward]

        {:error, reason} ->
          Logger.warning("Failed to create reward #{inspect(attrs)}: #{inspect(reason)}")
          []
      end
    end)
  end

  @doc """
  Deletes all given rewards. Returns `:ok` regardless of individual failures.
  """
  @spec delete_rewards(any(), list(Reward.t())) :: :ok
  def delete_rewards(_scope, []), do: :ok

  def delete_rewards(scope, rewards) do
    Enum.each(rewards, fn reward ->
      case Apis.twitch().delete_reward(scope, reward.id) do
        :ok -> Logger.info("Deleted reward #{reward.id} (#{reward.title})")
        {:error, reason} -> Logger.warning("Failed to delete reward #{reward.id}: #{inspect(reason)}")
      end
    end)

    :ok
  end
end
