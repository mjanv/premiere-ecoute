defmodule PremiereEcouteWeb.Mcp.Components.Profile do
  @moduledoc "Account information for the authenticated user"

  use Hermes.Server.Component,
    type: :resource,
    uri: "user://me/profile",
    mime_type: "application/json"

  alias Hermes.Server.Response

  @impl true
  def read(_params, %{assigns: %{current_user: user}} = frame) do
    payload = %{
      id: user.id,
      email: user.email,
      username: user.username,
      role: user.role,
      profile: Jason.decode!(Jason.encode!(user.profile))
    }

    {:reply, Response.json(Response.resource(), payload), frame}
  end
end
