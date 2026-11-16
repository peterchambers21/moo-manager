import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/moo_manager start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :moo_manager, CattleWeb.Endpoint, server: true
end

config :moo_manager, CattleWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :moo_manager, CattleWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/cattle_web/router\.ex$",
        ~r"lib/cattle_web/(controllers|live|components)/.*\.(ex|heex)$"
      ]
    ]
end

if config_env() == :prod do
  # Everything below has a sensible default so a fresh install runs with no
  # configuration. See the README for the environment variables.

  database_path = System.get_env("DATABASE_PATH") || Path.expand("moo_manager.db")
  File.mkdir_p!(Path.dirname(database_path))

  config :moo_manager, Cattle.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  # Cookies are signed with this secret. If SECRET_KEY_BASE isn't set, one is
  # generated on first boot and saved next to the database so sessions
  # survive restarts.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      (
        secret_file = Path.join(Path.dirname(database_path), "secret_key_base")

        case File.read(secret_file) do
          {:ok, secret} ->
            String.trim(secret)

          {:error, _} ->
            secret = :crypto.strong_rand_bytes(64) |> Base.encode64(padding: false)
            File.write!(secret_file, secret)
            File.chmod(secret_file, 0o600)
            secret
        end
      )

  # PHX_HOST is the public hostname (e.g. moo.example.com). When it's unset,
  # the app accepts connections at any address, so it can be reached by IP or
  # hostname on a local network.
  host = System.get_env("PHX_HOST")
  scheme = System.get_env("PHX_SCHEME") || "http"
  default_port = if scheme == "https", do: "443", else: System.get_env("PORT", "4000")

  config :moo_manager, CattleWeb.Endpoint,
    url: [
      host: host || "localhost",
      port: String.to_integer(System.get_env("PHX_URL_PORT") || default_port),
      scheme: scheme
    ],
    check_origin: if(host, do: true, else: false),
    http: [
      # Listen on all IPv4 interfaces. (An IPv6 `::` socket isn't dual-stack
      # on Windows, so IPv4 clients couldn't connect.) Set
      # LISTEN_LOCAL_ONLY=true to accept connections from this machine only.
      ip:
        if(System.get_env("LISTEN_LOCAL_ONLY") in ~w(true 1),
          do: {127, 0, 0, 1},
          else: {0, 0, 0, 0}
        )
    ],
    secret_key_base: secret_key_base
end
