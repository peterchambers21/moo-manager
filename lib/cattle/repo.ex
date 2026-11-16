defmodule Cattle.Repo do
  use Ecto.Repo,
    otp_app: :moo_manager,
    adapter: Ecto.Adapters.SQLite3
end
