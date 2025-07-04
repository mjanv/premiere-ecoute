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

    live_session :main,
      on_mount: [{PremiereEcouteWeb.UserAuth, :mount_current_scope}] do
      live "/", HomepageLive, :index
      live "/session/:id/overlay", Sessions.OverlayLive, :show
    end
  end

  scope "/", PremiereEcouteWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{PremiereEcouteWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/account", Accounts.AccountLive, :index
      live "/sessions/discography/album/select", Sessions.Discography.AlbumSelectionLive, :index
      live "/sessions", Sessions.SessionsLive, :index
      live "/session/:id", Sessions.SessionLive, :show
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

    get "/auth/:provider", Accounts.AuthController, :request
    get "/auth/:provider/callback", Accounts.AuthController, :callback
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
