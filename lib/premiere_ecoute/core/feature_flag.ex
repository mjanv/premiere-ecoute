defmodule PremiereEcoute.Core.FeatureFlag do
  @moduledoc false

  defdelegate enabled?(flag, opts \\ []), to: FunWithFlags
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
