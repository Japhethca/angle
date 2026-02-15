import Config
config :angle, Oban, testing: :manual
config :angle, token_signing_secret: "fjl5L2KXe/03eyOGjgh1JbGpPFZE48Ku"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true]

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :angle, Angle.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "angle_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :angle, AngleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "l5SWU9d9kJQAVaXQbyL9AzcmGrDYxZRH9yT0xaAKCdT2zjNno4GdZTApTcRJAYPN",
  server: false

# In test we don't send emails
config :angle, Angle.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Paystack: use mock client in tests
config :angle, :paystack_secret_key, "sk_test_fake_key_for_testing"
config :angle, :paystack_client, Angle.Payments.PaystackMock

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
