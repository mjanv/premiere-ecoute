defmodule PremiereEcouteWeb.Router do
  use PremiereEcouteWeb, :router

  import PremiereEcouteWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PremiereEcouteWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PremiereEcouteWeb do
    pipe_through :browser

    live_session :main,
      on_mount: [{PremiereEcouteWeb.UserAuth, :mount_current_scope}] do
      live "/", HomepageLive, :index
      live "/album/select", AlbumSelectionLive, :index
      live "/sessions", SessionsLive, :index
      live "/session/:id", SessionLive, :show
    end

    get "/auth/:provider", AuthController, :request
    get "/auth/:provider/callback", AuthController, :callback
  end

  scope "/", PremiereEcouteWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{PremiereEcouteWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", PremiereEcouteWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{PremiereEcouteWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  if Application.compile_env(:premiere_ecoute, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PremiereEcouteWeb.Telemetry
    end
  end
end
