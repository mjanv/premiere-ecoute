defmodule PremiereEcouteWeb.Hooks.Flash do
  @moduledoc """
  LiveView hook for flash messages.

  Subscribes authenticated users to their PubSub channel and handles info and error flash messages broadcasted to the user.
  """

  import Phoenix.LiveView

  @doc """
  Subscribes authenticated users to flash message broadcasts and attaches flash handling hook.

  Sets up PubSub subscription for the authenticated user's channel and registers a LiveView hook to process incoming flash messages during the mount lifecycle.
  """
  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) :: {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(_name, _params, _session, socket) do
    if connected?(socket) do
      if socket.assigns.current_scope && socket.assigns.current_scope.user do
        PremiereEcoute.PubSub.subscribe("user:#{socket.assigns.current_scope.user.id}")
      end
    end

    {:cont, attach_hook(socket, :flash, :handle_info, &maybe_flash/2)}
  end

  defp maybe_flash({:info, message}, socket), do: {:halt, put_flash(socket, :info, message)}
  defp maybe_flash({:error, message}, socket), do: {:halt, put_flash(socket, :error, message)}
  defp maybe_flash(_, socket), do: {:cont, socket}
end
