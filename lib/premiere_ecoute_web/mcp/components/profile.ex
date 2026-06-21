defmodule PremiereEcouteWeb.Mcp.Components.Profile do
  @moduledoc "Account information for the authenticated user"

  use Hermes.Server.Component,
    type: :resource,
    uri: "user://me/profile",
    mime_type: "application/json"

  alias Hermes.Server.Response
  alias PremiereEcoute.Accounts.User.Follow

  @impl true
  def read(_params, %{assigns: %{current_user: user}} = frame) do
    followed_streamers =
      Follow.following_list(user.id)
      |> Enum.map(fn u -> %{id: u.id, username: u.username, twitch_user_id: u.twitch && u.twitch.user_id} end)

    payload = %{
      id: user.id,
      email: user.email,
      username: user.username,
      role: user.role,
      profile: Jason.decode!(Jason.encode!(user.profile)),
      followed_streamers: followed_streamers
    }

    {:reply, Response.json(Response.resource(), payload), frame}
  end
end
