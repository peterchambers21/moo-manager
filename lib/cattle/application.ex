defmodule Cattle.Application do
  use Application

  def start(_type, _args) do
    children = [
      Cattle.Repo,
      {Registry, keys: :unique, name: Cattle.Registry, partitions: System.schedulers_online()},
      {Cattle.CowSupervisor, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MooManager.Supervisor)
  end
end
