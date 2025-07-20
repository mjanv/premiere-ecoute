defmodule PremiereEcouteWeb.Router do
  use PremiereEcouteWeb, :router

  import PremiereEcouteWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PremiereEcouteWeb.Layouts, :root}
    plug :protect_from_forgery
    # %{"content-security-policy" => "default-src 'self'"}
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug PremiereEcouteWeb.Plugs.RenewTokens
  end

  pipeline :webhook do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  scope "/", PremiereEcouteWeb do
    pipe_through :browser

    live_session :main, on_mount: [{PremiereEcouteWeb.UserAuth, :mount_current_scope}] do
      live "/", HomepageLive, :index
    end
  end

  scope "/users", PremiereEcouteWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{PremiereEcouteWeb.UserAuth, :mount_current_scope}] do
      live "/register", UserLive.Registration, :new
      live "/log-in", UserLive.Login, :new
      live "/log-in/:token", UserLive.Confirmation, :new
    end

    post "/log-in", UserSessionController, :create
    delete "/log-out", UserSessionController, :delete
  end

  scope "/users", PremiereEcouteWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :users, on_mount: [{PremiereEcouteWeb.UserAuth, :require_authenticated}] do
      live "/settings", UserLive.Settings, :edit
      live "/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/account", Accounts.AccountLive, :index
    end

    post "/update-password", UserSessionController, :update_password
  end

  scope "/sessions", PremiereEcouteWeb do
    pipe_through [:browser]

    live_session :sessions, on_mount: [{PremiereEcouteWeb.UserAuth, :require_streamer}] do
      live "/", Sessions.SessionsLive, :index
      live "/:id", Sessions.SessionLive, :show
      live "/discography/album/select", Sessions.Discography.AlbumSelectionLive, :index
    end

    live_session :public_sessions do
      live "/:id/overlay", Sessions.OverlayLive, :show
    end
  end

  scope "/admin", PremiereEcouteWeb.Admin do
    pipe_through [:browser]

    live_session :admin, on_mount: [{PremiereEcouteWeb.UserAuth, :require_admin}] do
      live "/", AdminLive, :index
      live "/users", AdminUsersLive, :index
      live "/albums", AdminAlbumsLive, :index
      live "/sessions", AdminSessionsLive, :index
    end
  end

  scope "/auth", PremiereEcouteWeb do
    pipe_through [:browser]

    get "/:provider", Accounts.AuthController, :request
    get "/:provider/callback", Accounts.AuthController, :callback
  end

  scope "/webhooks", PremiereEcouteWeb.Webhooks do
    pipe_through :webhook

    post "/twitch", TwitchController, :handle_event
  end

  if Application.compile_env(:premiere_ecoute, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PremiereEcouteWeb.Telemetry
    end
  end
end
