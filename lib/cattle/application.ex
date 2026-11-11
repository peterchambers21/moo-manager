defmodule Cattle.Application do
  use Application

  def start(_type, _args) do
    children = [
      Cattle.Repo,
      {Registry,
       keys: :unique, name: Cattle.CattleRegistry, partitions: System.schedulers_online()},
      {Task.Supervisor, name: Cattle.TaskSupervisor},
      {Cattle.CowSupervisor, []}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MooManager.Supervisor)
  end
end
