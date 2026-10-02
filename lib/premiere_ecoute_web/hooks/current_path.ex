defmodule PremiereEcouteWeb.Hooks.CurrentPath do
  @moduledoc """
  LiveView hook assigning `:current_path` (path and query of the page being displayed).

  Updated on every params change, so pages can link elsewhere with a `return_to` that includes their live filters.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  alias PremiereEcouteWeb.ReturnTo

  @doc """
  Attaches a `handle_params` hook on router-mounted LiveViews.
  """
  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) :: {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(_name, _params, _session, %{router: nil} = socket), do: {:cont, assign(socket, :current_path, nil)}

  def on_mount(_name, _params, _session, socket) do
    socket =
      attach_hook(socket, :current_path, :handle_params, fn _params, uri, socket ->
        {:cont, assign(socket, :current_path, ReturnTo.current_path(uri))}
      end)

    {:cont, socket}
  end
end
