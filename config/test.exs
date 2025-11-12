import Config

config :moo_manager, Cattle.Repo,
  # or test user
  username: "cattle_user",
  password: "changeme",
  hostname: "localhost",
  database: "cattle_test",
  # important for tests
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
