defmodule PremiereEcoute.Apis.Streaming.TwitchApi.Rewards do
  @moduledoc """
  Twitch channel points rewards API.

  Creates, retrieves, updates, and deletes custom channel point rewards,
  and manages redemption statuses.
  """

  alias PremiereEcoute.Accounts.Scope
  alias PremiereEcoute.Apis.Streaming.TwitchApi
  alias PremiereEcoute.Twitch.Redemption
  alias PremiereEcoute.Twitch.Reward

  @type create_attrs :: %{
          required(:title) => String.t(),
          required(:cost) => pos_integer(),
          optional(:prompt) => String.t(),
          optional(:is_enabled) => boolean(),
          optional(:background_color) => String.t(),
          optional(:is_user_input_required) => boolean(),
          optional(:should_redemptions_skip_request_queue) => boolean(),
          optional(:is_max_per_stream_enabled) => boolean(),
          optional(:max_per_stream) => pos_integer(),
          optional(:is_max_per_user_per_stream_enabled) => boolean(),
          optional(:max_per_user_per_stream) => pos_integer(),
          optional(:is_global_cooldown_enabled) => boolean(),
          optional(:global_cooldown_seconds) => pos_integer()
        }

  @type update_attrs :: %{
          optional(:title) => String.t(),
          optional(:cost) => pos_integer(),
          optional(:prompt) => String.t(),
          optional(:is_enabled) => boolean(),
          optional(:background_color) => String.t(),
          optional(:is_user_input_required) => boolean(),
          optional(:should_redemptions_skip_request_queue) => boolean(),
          optional(:is_max_per_stream_enabled) => boolean(),
          optional(:max_per_stream) => pos_integer(),
          optional(:is_max_per_user_per_stream_enabled) => boolean(),
          optional(:max_per_user_per_stream) => pos_integer(),
          optional(:is_global_cooldown_enabled) => boolean(),
          optional(:global_cooldown_seconds) => pos_integer()
        }

  @doc """
  Creates a custom channel point reward.
  """
  @spec create_reward(Scope.t(), create_attrs()) :: {:ok, Reward.t()} | {:error, term()}
  def create_reward(%Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope, attrs) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.post(
      url: "/channel_points/custom_rewards",
      json: attrs,
      params: %{broadcaster_id: broadcaster_id}
    )
    |> TwitchApi.handle(200, fn %{"data" => [reward | _]} -> Reward.parse(reward) end)
  end

  @doc """
  Returns all custom rewards for the broadcaster.
  """
  @spec get_rewards(Scope.t()) :: {:ok, [Reward.t()]} | {:error, term()}
  def get_rewards(%Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.get(
      url: "/channel_points/custom_rewards",
      params: %{broadcaster_id: broadcaster_id}
    )
    |> TwitchApi.handle(200, fn %{"data" => rewards} -> Enum.map(rewards, &Reward.parse/1) end)
  end

  @doc """
  Updates an existing custom reward.
  """
  @spec update_reward(Scope.t(), String.t(), update_attrs()) :: {:ok, Reward.t()} | {:error, term()}
  def update_reward(%Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope, reward_id, attrs) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.patch(
      url: "/channel_points/custom_rewards",
      json: attrs,
      params: %{broadcaster_id: broadcaster_id, id: reward_id}
    )
    |> TwitchApi.handle(200, fn %{"data" => [reward | _]} -> Reward.parse(reward) end)
  end

  @doc """
  Deletes a custom reward.
  """
  @spec delete_reward(Scope.t(), String.t()) :: :ok | {:error, term()}
  def delete_reward(%Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope, reward_id) do
    with {:ok, _} <-
           scope
           |> TwitchApi.api()
           |> TwitchApi.delete(
             url: "/channel_points/custom_rewards",
             params: %{broadcaster_id: broadcaster_id, id: reward_id}
           )
           |> TwitchApi.handle(204, fn _ -> nil end) do
      :ok
    end
  end

  @doc """
  Returns redemptions for a reward filtered by status.
  """
  @spec get_redemptions(Scope.t(), String.t(), Redemption.status()) ::
          {:ok, [Redemption.t()]} | {:error, term()}
  def get_redemptions(
        %Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope,
        reward_id,
        status
      ) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.get(
      url: "/channel_points/custom_rewards/redemptions",
      params: %{
        broadcaster_id: broadcaster_id,
        reward_id: reward_id,
        status: status |> Atom.to_string() |> String.upcase()
      }
    )
    |> TwitchApi.handle(200, fn %{"data" => redemptions} ->
      Enum.map(redemptions, &Redemption.parse/1)
    end)
  end

  @doc """
  Updates the status of a redemption to :fulfilled or :canceled.
  """
  @spec update_redemption_status(Scope.t(), String.t(), String.t(), Redemption.status()) ::
          {:ok, Redemption.t()} | {:error, term()}
  def update_redemption_status(
        %Scope{user: %{twitch: %{user_id: broadcaster_id}}} = scope,
        reward_id,
        redemption_id,
        status
      ) do
    scope
    |> TwitchApi.api()
    |> TwitchApi.patch(
      url: "/channel_points/custom_rewards/redemptions",
      json: %{status: status |> Atom.to_string() |> String.upcase()},
      params: %{
        broadcaster_id: broadcaster_id,
        reward_id: reward_id,
        id: redemption_id
      }
    )
    |> TwitchApi.handle(200, fn %{"data" => [redemption | _]} -> Redemption.parse(redemption) end)
  end
end
