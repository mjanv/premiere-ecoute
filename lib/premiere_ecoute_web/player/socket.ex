defmodule PremiereEcouteWeb.Player.Socket do
  @moduledoc """
  Phoenix Socket of the desktop player.

  Authenticates the connection with the OAuth access token sent in the `X-Access-Token` header and identifies the player by its user. One player per user.
  """

  use Phoenix.Socket

  alias Boruta.Oauth.Authorization.AccessToken

  channel "desktop:*", PremiereEcouteWeb.Player.Channel

  @impl true
  def connect(_params, socket, %{x_headers: headers}) do
    with {_, token} <- List.keyfind(headers, "x-access-token", 0),
         {:ok, %{sub: sub, scope: scope}} <- AccessToken.authorize(value: token),
         true <- "player" in String.split(scope, " ", trim: true),
         {user_id, ""} <- Integer.parse(sub) do
      {:ok, assign(socket, :user_id, user_id)}
    else
      _ -> :error
    end
  end

  @impl true
  def id(socket), do: "desktop_socket:#{socket.assigns.user_id}"
end
