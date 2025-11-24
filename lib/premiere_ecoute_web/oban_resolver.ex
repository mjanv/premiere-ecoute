defmodule PremiereEcouteWeb.ObanResolver do
  @moduledoc false

  @behaviour Oban.Web.Resolver

  @impl true
  def resolve_user(%{assigns: %{current_scope: %{user: user}}}), do: user
  def resolve_user(_), do: nil

  @impl true
  def resolve_access(%{role: :admin}), do: :all
  def resolve_access(_), do: {:forbidden, "/"}
end
