import Config

config :moo_manager, Cattle.Repo,
  username: "cattle_user",
  password: "changeme",
  hostname: "localhost",
  database: "cattle_dev",
  pool_size: 10,
  show_sensitive_data_on_connection_error: true
