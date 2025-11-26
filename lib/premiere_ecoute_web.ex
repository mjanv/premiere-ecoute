defmodule PremiereEcouteWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such as controllers, components, channels, and so on.

  This can be used in your application as:

      use PremiereEcouteWeb, :controller
      use PremiereEcouteWeb, :html

  The definitions below will be executed for every controller, component, etc, so keep them short and clean, focused on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions below. Instead, define additional modules and import those modules here.
  """

  use Boundary,
    deps: [PremiereEcouteCore, PremiereEcoute],
    exports: [
      Endpoint,
      CoreComponents,
      Components.ActivityCard,
      Components.AlbumTrackDisplay,
      Components.Card,
      Components.EmptyState,
      Components.LoadingState,
      Components.Modal,
      Components.PageHeader,
      Components.Search,
      Components.StatsCard,
      Components.StatusBadge
    ]

  def static_paths, do: ~w(doc assets fonts images uploads favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      on_mount PremiereEcouteWeb.Hooks.RestoreLocale
      on_mount PremiereEcouteWeb.Hooks.Flash

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller, only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      use Gettext, backend: PremiereEcoute.Gettext

      import Phoenix.HTML
      import PremiereEcouteWeb.CoreComponents
      import PremiereEcouteWeb.Components.Modal

      alias Phoenix.LiveView.AsyncResult
      alias Phoenix.LiveView.JS
      alias PremiereEcouteWeb.Layouts

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: PremiereEcouteWeb.Endpoint,
        router: PremiereEcouteWeb.Router,
        statics: PremiereEcouteWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])
end
