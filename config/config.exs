import Config

config :moo_manager, ecto_repos: [Cattle.Repo]

# --- DEBUG (TEMPORARY) ---
path = Path.join([__DIR__, "#{config_env()}.exs"])
IO.puts(">>> importing: #{path}  (exists? #{File.exists?(path)})")
# --- END DEBUG ---

import_config "#{config_env()}.exs"
