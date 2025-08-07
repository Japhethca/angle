[
  import_deps: [
    :ash_admin,
    :ash_oban,
    :oban,
    :ash_authentication,
    :ash_json_api,
    :ash_graphql,
    :absinthe,
    :ash_postgres,
    :ash_phoenix,
    :ash,
    :reactor,
    :ecto,
    :ecto_sql,
    :phoenix
  ],
  subdirectories: ["priv/*/migrations"],
  plugins: [Absinthe.Formatter, Spark.Formatter, Phoenix.LiveView.HTMLFormatter],
  inputs: [
    ".claude.exs",
    "{mix,.formatter}.exs",
    "*.{heex,ex,exs}",
    "{config,lib,test}/**/*.{heex,ex,exs}",
    "priv/*/seeds.exs"
  ]
]
