defmodule AngleWeb.Router do
  use AngleWeb, :router

  # Import the auth plugs
  import AngleWeb.Plugs.Auth

  pipeline :graphql do
    plug AshGraphql.Plug
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AngleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # Add user loading to all browser requests
    plug :load_current_user
    plug Inertia.Plug
    plug AngleWeb.Plugs.NavCategories
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # New authentication pipelines
  pipeline :require_auth do
    plug :ensure_authenticated
  end

  pipeline :api_auth do
    plug :validate_api_token
  end

  # Public API endpoints (for catalog browsing, etc.)
  scope "/api/v1/public" do
    pipe_through [:api]

    forward "/docs", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/v1/open_api",
      default_model_expand_depth: 4
  end

  # Protected API endpoints (require authentication)
  scope "/api/v1" do
    pipe_through [:api, :api_auth]

    forward "/", AngleWeb.AshJsonApiRouter
  end

  scope "/gql" do
    pipe_through [:graphql, :api_auth]

    forward "/playground", Absinthe.Plug.GraphiQL,
      schema: Module.concat(["AngleWeb.GraphqlSchema"]),
      socket: Module.concat(["AngleWeb.GraphqlSocket"]),
      interface: :simple

    forward "/", Absinthe.Plug, schema: Module.concat(["AngleWeb.GraphqlSchema"])
  end

  # Public routes
  scope "/", AngleWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/items/:slug", ItemsController, :show
    get "/categories", CategoriesController, :index
    get "/categories/:slug", CategoriesController, :show
    get "/categories/:slug/:sub_slug", CategoriesController, :show_subcategory
    get "/terms", PageController, :terms
    get "/privacy", PageController, :privacy
    post "/rpc/run", AshTypescriptRpcController, :run
    post "/rpc/validate", AshTypescriptRpcController, :validate
  end

  # Auth routes (guest only)
  scope "/auth", AngleWeb do
    pipe_through :browser

    get "/login", AuthController, :login
    post "/login", AuthController, :do_login
    get "/register", AuthController, :register
    post "/register", AuthController, :do_register
    get "/verify-account", AuthController, :verify_account
    post "/verify-account", AuthController, :do_verify_account
    post "/resend-otp", AuthController, :resend_otp
    get "/forgot-password", AuthController, :forgot_password
    post "/forgot-password", AuthController, :do_forgot_password
    get "/reset-password/:token", AuthController, :reset_password
    post "/reset-password", AuthController, :do_reset_password
    get "/confirm-new-user/:token", AuthController, :confirm_new_user
    post "/logout", AuthController, :logout
  end

  # OAuth callback routes (handled by AshAuthentication)
  scope "/auth" do
    pipe_through :browser
    forward "/", AngleWeb.AuthPlug
  end

  # Protected routes
  scope "/", AngleWeb do
    pipe_through [:browser, :require_auth]

    get "/dashboard", DashboardController, :index
    get "/bids", BidsController, :index
    get "/watchlist", WatchlistController, :index
    get "/profile", ProfileController, :show
    get "/store", StoreDashboardController, :index
    get "/store/listings", StoreDashboardController, :listings
    get "/store/listings/new", StoreDashboardController, :new
    get "/store/listings/:id/preview", StoreDashboardController, :preview
    get "/store/listings/:id/edit", StoreDashboardController, :edit
    get "/store/payments", StoreDashboardController, :payments
    get "/store/profile", StoreDashboardController, :profile
    get "/settings", SettingsController, :index
    get "/settings/account", SettingsController, :account
    get "/settings/store", SettingsController, :store
    get "/settings/security", SettingsController, :security
    get "/settings/payments", SettingsController, :payments
    get "/settings/notifications", SettingsController, :notifications
    get "/settings/preferences", SettingsController, :preferences
    get "/settings/legal", SettingsController, :legal
    get "/settings/support", SettingsController, :support

    # Image upload endpoints (JSON)
    post "/uploads", UploadController, :create
    delete "/uploads/:id", UploadController, :delete
    patch "/uploads/reorder", UploadController, :reorder
  end

  # Public store profile (catch-all with :identifier must come after specific /store/* routes)
  scope "/", AngleWeb do
    pipe_through :browser

    get "/store/:identifier", StoreController, :show
  end

  # Payments API endpoints (same-origin, session-authenticated with CSRF)
  scope "/api/payments", AngleWeb do
    pipe_through [:browser, :require_auth]

    post "/initialize-card", PaymentsController, :initialize_card
    post "/verify-card", PaymentsController, :verify_card
    delete "/payment-methods/:id", PaymentsController, :delete_payment_method
    post "/add-payout", PaymentsController, :add_payout
    delete "/payout-methods/:id", PaymentsController, :delete_payout_method
    get "/banks", PaymentsController, :list_banks
    post "/pay-order", PaymentsController, :pay_order
    post "/verify-order-payment", PaymentsController, :verify_order_payment
  end

  # Other scopes may use custom stacks.
  # scope "/api", AngleWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:angle, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AngleWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:angle, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
