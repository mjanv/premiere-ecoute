defmodule PremiereEcouteCore.FeatureFlag do
  @moduledoc """
  Feature flag utilities.

  Provides a wrapper around FunWithFlags for managing feature flags with user-based and role-based targeting.
  """

  defdelegate enabled?(flag, opts \\ []), to: FunWithFlags

  @doc "Checks if a feature flag is disabled."
  @spec disabled?(atom(), keyword()) :: boolean()
  def disabled?(flag, opts \\ []), do: not enabled?(flag, opts)

  defdelegate enable(flag, opts \\ []), to: FunWithFlags
  defdelegate disable(flag, opts \\ []), to: FunWithFlags
  defdelegate clear(flag, opts \\ []), to: FunWithFlags
end

defimpl FunWithFlags.Actor, for: PremiereEcoute.Accounts.User do
  def id(user), do: "user:#{user.id}"
end

defimpl FunWithFlags.Group, for: PremiereEcoute.Accounts.User do
  def in?(%{role: role}, group), do: Atom.to_string(role) == group
end
