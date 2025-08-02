defmodule PremiereEcouteWeb.Router do
  use PremiereEcouteWeb, :router

  import Oban.Web.Router
  import PhoenixStorybook.Router
  import PremiereEcouteWeb.UserAuth

  alias PremiereEcouteWeb.Plugs
  alias PremiereEcouteWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PremiereEcouteWeb.Layouts, :root}
    plug :protect_from_forgery
    # %{"content-security-policy" => "default-src 'self'"}
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug Plugs.RenewTokens
    plug Plugs.SetLocale
  end

  pipeline :webhook do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  scope "/" do
    storybook_assets()
  end

  scope "/", PremiereEcouteWeb do
    pipe_through [:browser]

    live_session :main, on_mount: [{UserAuth, :current_scope}] do
      live "/", HomepageLive, :index
    end

    live_storybook("/storybook", backend_module: PremiereEcouteWeb.Storybook)
  end

  scope "/users", PremiereEcouteWeb.Accounts do
    pipe_through [:browser]

    live_session :current_user, on_mount: [{UserAuth, :current_scope}] do
      live "/register", UserRegistrationLive, :new
      live "/log-in", UserLoginLive, :new
      live "/log-in/:token", UserConfirmationLive, :new
    end

    post "/log-in", UserSessionController, :create
    delete "/log-out", UserSessionController, :delete
  end

  scope "/users", PremiereEcouteWeb.Accounts do
    pipe_through [:browser, :require_authenticated_user]

    live_session :users, on_mount: [{UserAuth, :current_scope}] do
      live "/settings", UserSettingsLive, :edit
      live "/settings/confirm-email/:token", UserSettingsLive, :confirm_email
      live "/account", AccountLive, :index
      live "/follows", FollowsLive, :index
    end

    post "/update-password", UserSessionController, :update_password
  end

  scope "/sessions", PremiereEcouteWeb.Sessions do
    pipe_through [:browser]

    live_session :sessions, on_mount: [{UserAuth, :streamer}] do
      live "/", SessionsLive, :index
      live "/:id", SessionLive, :show
      live "/discography/album/select", Discography.AlbumSelectionLive, :index
      live "/wrapped/retrospective", RetrospectiveLive, :index
    end

    live "/:id/overlay", OverlayLive, :show
  end

  scope "/admin", PremiereEcouteWeb.Admin do
    pipe_through [:browser]

    live_session :admin, on_mount: [{UserAuth, :admin}] do
      live "/", AdminLive, :index
      live "/users", AdminUsersLive, :index
      live "/albums", AdminAlbumsLive, :index
      live "/sessions", AdminSessionsLive, :index
    end

    # AIDEV-NOTE: Impersonation routes for admin users only
    pipe_through [:require_authenticated_user]
    post "/impersonation", ImpersonationController, :create
    delete "/impersonation", ImpersonationController, :delete
  end

  scope "/auth", PremiereEcouteWeb.Accounts do
    pipe_through [:browser]

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  scope "/webhooks", PremiereEcouteWeb.Webhooks do
    pipe_through [:webhook]

    post "/twitch", TwitchController, :handle
  end

  scope "/changelog", PremiereEcouteWeb.Static.Changelog do
    pipe_through :browser

    get "/", ChangelogController, :index
    get "/:id", ChangelogController, :show
  end

  scope "/legal", PremiereEcouteWeb.Static.Legal do
    pipe_through :browser

    get "/privacy", LegalController, :privacy
    get "/cookies", LegalController, :cookies
    get "/terms", LegalController, :terms
    get "/contact", LegalController, :contact
  end

  if Application.compile_env(:premiere_ecoute, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:browser]

      live_dashboard "/dashboard", metrics: PremiereEcouteWeb.Telemetry
      oban_dashboard("/oban")
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
