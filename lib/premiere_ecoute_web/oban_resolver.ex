defmodule PremiereEcouteWeb.ObanResolver do
  @moduledoc """
  Oban Web resolver.

  Implements authentication and authorization for the Oban Web dashboard, restricting access to admin users only.
  """

  @behaviour Oban.Web.Resolver

  @impl true
  def resolve_user(%{assigns: %{current_scope: %{user: user}}}), do: user
  def resolve_user(_), do: nil

  @impl true
  def resolve_access(%{role: :admin}), do: :all
  def resolve_access(_), do: {:forbidden, "/"}
end
