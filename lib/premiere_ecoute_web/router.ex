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
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user

    # plug PlugContentSecurityPolicy,
    #   nonces_for: [:script_src, :style_src],
    #   directives: %{
    #     script_src: ~w('self' 'unsafe-eval' https://unpkg.com),
    #     style_src: ~w('self' 'unsafe-hashes' https://fonts.googleapis.com),
    #     font_src: ~w('self' https://fonts.gstatic.com),
    #     style_src_attr: ~w('self' 'unsafe-hashes' 'unsafe-inline')
    #   }

    plug Plugs.RenewTokens
    plug Plugs.SetLocale
  end

  pipeline :webhook do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :app do
    plug :accepts, ["html"]
    plug :put_secure_browser_headers
    plug :auth
  end

  defp auth(conn, _opts) do
    Plug.BasicAuth.basic_auth(conn, Application.get_env(:premiere_ecoute, :feature_flags))
  end

  scope "/" do
    storybook_assets()
  end

  scope "/", PremiereEcouteWeb do
    pipe_through [:browser]

    get "/health", HealthController, :index
    oban_dashboard("/oban", resolver: PremiereEcouteWeb.ObanResolver)

    live_session :main, on_mount: [{UserAuth, :current_scope}] do
      live "/", HomepageLive, :index
      live "/playground", PlaygroundLive, :index
    end

    pipe_through [:require_authenticated_user]

    live_session :home, on_mount: [{UserAuth, :viewer}] do
      live "/home", HomeLive, :index
    end
  end

  scope "/users", PremiereEcouteWeb.Accounts do
    pipe_through [:browser]

    live_session :current_user, on_mount: [{UserAuth, :current_scope}] do
      live "/register", UserRegistrationLive, :new
      live "/log-in", UserLoginLive, :new
      live "/log-in/:token", UserConfirmationLive, :new
      live "/terms-acceptance", TermsAcceptanceLive, :index
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

  scope "/", PremiereEcouteWeb.Billboards do
    pipe_through [:browser]

    live_session :public_billboard, on_mount: [{UserAuth, :current_scope}] do
      live "/billboard", BillboardLive, :index
      live "/billboards/:id/dashboard", DashboardLive, :show
      live "/billboards/:id/submission/new", SubmissionLive, :new
    end

    pipe_through [:require_authenticated_user]

    live_session :viewer_billboard, on_mount: [{UserAuth, :viewer}] do
      live "/billboards/submissions", SubmissionsLive, :index
    end

    live_session :streamer_billboard, on_mount: [{UserAuth, :streamer}] do
      live "/billboards", IndexLive, :index
      live "/billboards/new", NewLive, :new
      live "/billboards/:id", ShowLive, :show
    end
  end

  scope "/playlists", PremiereEcouteWeb.Playlists do
    pipe_through [:browser]

    live_session :playlists, on_mount: [{UserAuth, :viewer}] do
      live "/", LibraryLive, :index
      live "/rules", RulesLive, :index
      live "/workflows", WorkflowsLive, :index
      live "/:id", PlaylistLive, :show
    end
  end

  scope "/festivals", PremiereEcouteWeb.Festivals do
    pipe_through [:browser]

    live_session :festivals, on_mount: [{UserAuth, :streamer}] do
      live "/new", PosterLive, :index
    end
  end

  scope "/sessions", PremiereEcouteWeb.Sessions do
    pipe_through [:browser]

    live_session :overlays, on_mount: [{UserAuth, :current_scope}] do
      live "/overlay/:id", OverlayLive, :show
    end

    live_session :retrospective, on_mount: [{UserAuth, :current_scope}] do
      live "/:id/retrospective", RetrospectiveLive, :show
    end

    live_session :sessions, on_mount: [{UserAuth, :streamer}] do
      live "/", SessionsLive, :index
      live "/new", AlbumSelectionLive, :index
      live "/:id", SessionLive, :show
    end
  end

  scope "/retrospective", PremiereEcouteWeb.Retrospective do
    pipe_through [:browser]

    live_session :streamer_retrospective, on_mount: [{UserAuth, :streamer}] do
      live "/history", HistoryLive, :index
    end

    live_session :viewer_retrospective, on_mount: [{UserAuth, :viewer}] do
      live "/votes", VotesLive, :index
    end
  end

  scope "/admin", PremiereEcouteWeb.Admin do
    pipe_through [:browser]

    live_session :donations_overlay, on_mount: [{UserAuth, :current_scope}] do
      live "/donations/overlay", Donations.OverlayLive, :index
    end

    live_session :admin, on_mount: [{UserAuth, :admin}] do
      live "/", AdminLive, :index
      live "/users", AdminUsersLive, :index
      live "/albums", AdminAlbumsLive, :index
      live "/sessions", AdminSessionsLive, :index
      live "/billboards", AdminBillboardsLive, :index
      live "/donations", Donations.DonationsLive, :index
      live "/donations/goals/:id", Donations.GoalLive, :show
    end

    pipe_through [:require_authenticated_user]
    post "/impersonation", ImpersonationController, :create
    delete "/impersonation", ImpersonationController, :delete
  end

  scope "/auth", PremiereEcouteWeb.Accounts do
    pipe_through [:browser]

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    get "/:provider/complete", AuthController, :complete
  end

  scope "/extension", PremiereEcouteWeb.Extension do
    pipe_through :api

    get "/tracks/current/:broadcaster_id", TrackController, :current_track
    post "/tracks/like", TrackController, :like_track
  end

  scope "/webhooks", PremiereEcouteWeb.Webhooks do
    pipe_through [:webhook]

    post "/twitch", TwitchController, :handle
    post "/twilio", TwilioController, :handle
    post "/buymeacoffee", BuyMeACoffeeController, :handle
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

  scope "/feature-flags" do
    pipe_through [:app]

    forward "/", FunWithFlags.UI.Router, namespace: "feature-flags"
  end

  if Application.compile_env(:premiere_ecoute, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through [:browser]

      live_dashboard("/dashboard", metrics: PremiereEcouteWeb.Telemetry)
      live_storybook("/storybook", backend_module: PremiereEcouteWeb.Storybook)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
