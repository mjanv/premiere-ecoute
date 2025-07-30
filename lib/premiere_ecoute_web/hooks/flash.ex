# the same MyAppWeb.Flash module as earlier

defmodule PremiereEcouteWeb.Hooks.Flash do
  @moduledoc false

  import Phoenix.LiveView

  def on_mount(_name, _params, _session, socket) do
    if connected?(socket) do
      PremiereEcoute.PubSub.subscribe("user:#{socket.assigns.current_scope.user.id}")
    end

    {:cont, attach_hook(socket, :flash, :handle_info, &maybe_flash/2)}
  end

  defp maybe_flash({:info, message}, socket), do: {:halt, put_flash(socket, :info, message)}
  defp maybe_flash({:error, message}, socket), do: {:halt, put_flash(socket, :error, message)}
  defp maybe_flash(_, socket), do: {:cont, socket}
end
