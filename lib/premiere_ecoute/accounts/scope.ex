defmodule PremiereEcoute.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `PremiereEcoute.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias PremiereEcoute.Accounts.User

  @type t :: %__MODULE__{user: User.t() | nil, admin: User.t() | nil, impersonating?: boolean()}
  defstruct user: nil, admin: nil, impersonating?: false

  @doc "Creates a scope for the given user."
  def for_user(%User{} = user), do: %__MODULE__{user: user}
  def for_user({:ok, %User{} = user}), do: %__MODULE__{user: user}
  def for_user(nil), do: nil

  @doc "Creates an impersonation scope where an admin is impersonating another user."
  def for_impersonation(%User{role: :admin} = admin, %User{} = user) do
    %__MODULE__{user: user, admin: admin, impersonating?: true}
  end

  @doc "Ends impersonation and returns to the original admin scope."
  def end_impersonation(%__MODULE__{admin: %User{} = admin}), do: for_user(admin)
  def end_impersonation(scope), do: scope

  def valid?(%{assigns: %{current_scope: current_scope}}), do: valid?(current_scope)
  def valid?(%__MODULE__{user: %User{}}), do: true
  def valid?(_), do: false
end
