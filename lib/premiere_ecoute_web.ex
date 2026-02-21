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

  @doc """
  Returns list of static file paths served by the application.

  These paths are publicly accessible without authentication and include documentation, assets, fonts, images, uploads, and standard web files.
  """
  @spec static_paths() :: [String.t()]
  def static_paths, do: ~w(doc assets fonts images uploads favicon.ico robots.txt)

  @doc """
  Defines router configuration for Phoenix routes.

  Injects Phoenix.Router with helper-free routing and standard web imports for connection and controller handling.
  """
  @spec router() :: Macro.t()
  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  @doc """
  Defines channel configuration for Phoenix channels.

  Injects Phoenix.Channel functionality for real-time bidirectional communication with clients.
  """
  @spec channel() :: Macro.t()
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  @doc """
  Defines controller configuration for Phoenix controllers.

  Injects Phoenix.Controller with HTML and JSON format support, Plug.Conn utilities, and verified routes.
  """
  @spec controller() :: Macro.t()
  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  @doc """
  Defines LiveView configuration for Phoenix LiveView modules.

  Injects Phoenix.LiveView with locale restoration and flash message hooks, plus HTML helpers for component rendering.
  """
  @spec live_view() :: Macro.t()
  def live_view do
    quote do
      use Phoenix.LiveView

      on_mount PremiereEcouteWeb.Hooks.RestoreLocale
      on_mount PremiereEcouteWeb.Hooks.Flash
      on_mount PremiereEcouteWeb.Hooks.RateLimits

      unquote(html_helpers())
    end
  end

  @doc """
  Defines LiveComponent configuration for Phoenix LiveComponent modules.

  Injects Phoenix.LiveComponent functionality with HTML helpers for building reusable stateful components within LiveViews.
  """
  @spec live_component() :: Macro.t()
  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  @doc """
  Defines HTML configuration for Phoenix Component modules.

  Injects Phoenix.Component with controller helpers for CSRF tokens and view metadata, plus standard HTML helpers and component imports.
  """
  @spec html() :: Macro.t()
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

  @doc """
  Defines verified routes configuration for compile-time route verification.

  Injects Phoenix.VerifiedRoutes with endpoint, router, and static paths for type-safe routing with compile-time path validation.
  """
  @spec verified_routes() :: Macro.t()
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
