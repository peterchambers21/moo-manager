import Config

config :moo_manager, ecto_repos: [Cattle.Repo]

import_config "#{config_env()}.exs"
