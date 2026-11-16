# MooManager 🐄
*A modern cattle and feedlot management system built with Elixir.*

## Overview
MooManager is an Elixir-based management platform designed to streamline the operations of cattle farms and feedlots.
It helps producers and feedlot operators track livestock, feed, weight gain, health records, and other key metrics. It's a single self-hosted app with its own web interface and an embedded SQLite database, so there's no separate database server to run.

## Features
- 📋 **Livestock Management:** Register animals, move them between pens, and record shipping or deaths.
- ⚖️ **Weigh-ins & Gain:** Record weights and see average daily gain per animal, pen, and herd.
- 💉 **Health Records:** Log observations, treatments, and vaccinations. Shipping is blocked while a drug withdrawal period is active.
- 🧾 **Feed Tracking:** Record feed deliveries per pen, with totals and lb per head per day over any date range.
- 🖥️ **Web Dashboard:** Herd overview, pen summaries, and a list of animals under withdrawal.

## Tech Stack
- **Language:** [Elixir](https://elixir-lang.org/)
- **Web:** [Phoenix](https://www.phoenixframework.org/) + [LiveView](https://hexdocs.pm/phoenix_live_view)
- **Database:** SQLite via [Ecto](https://hexdocs.pm/ecto/Ecto.html) and `ecto_sqlite3`
- **Testing:** ExUnit

## Running it yourself

> ⚠️ MooManager has **no login yet**. Anyone who can reach the port can view and change the data. Run it on a trusted network, or put it behind a reverse proxy with authentication before exposing it to the internet.

### Option 1: Docker (recommended)

```sh
git clone <this repo> moo_manager
cd moo_manager
docker compose up -d
```

Open <http://localhost:4000>, or `http://<this-machine's-IP>:4000` from another device on your network.
Your data lives in the `moo_data` Docker volume. The database migrates itself on startup.

### Option 2: Build a release (no Docker)

Requires Elixir 1.18+ and Erlang/OTP 27+ on the build machine. The resulting release doesn't need Elixir installed to run.

```sh
export MIX_ENV=prod
mix deps.get --only prod
mix assets.setup
mix assets.deploy
mix release

_build/prod/rel/moo_manager/bin/server       # on Windows: bin\server.bat
```

The database is created as `moo_manager.db` in the working directory unless `DATABASE_PATH` is set.

### Configuration

Everything is optional. The defaults work for a home or farm-office install.

| Variable | Default | Purpose |
|---|---|---|
| `PORT` | `4000` | Port to listen on |
| `DATABASE_PATH` | `./moo_manager.db` (`/data/moo_manager.db` in Docker) | SQLite database file |
| `SECRET_KEY_BASE` | generated and saved next to the database on first run | Signs cookies |
| `PHX_HOST` | unset | Public hostname, e.g. `moo.example.com`. Set this when serving on a domain. |
| `PHX_SCHEME` | `http` | Set to `https` when behind an HTTPS reverse proxy |
| `LISTEN_LOCAL_ONLY` | `false` | `true` accepts connections from this machine only |

**HTTPS:** MooManager serves plain HTTP. For internet-facing installs, put a reverse proxy such as [Caddy](https://caddyserver.com/) in front of it, which gets certificates automatically, and set `PHX_HOST` and `PHX_SCHEME=https`.

**Backups:** Copy the database file (and `secret_key_base` beside it) while the app is stopped. Or, while it's running, use `sqlite3 moo_manager.db ".backup backup.db"`.

## Development

```sh
mix setup          # deps, database, assets
mix phx.server     # http://localhost:4000, with live reload
mix test
```
