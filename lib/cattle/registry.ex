# CattleRegistry starts and manages the registry for cow processes

defmodule Cattle.CattleRegistry do
  @moduledoc """
  A simple `Supervisor` that runs a unique-key `Registry` for naming cow processes.

  Add this supervisor to your application tree before starting any cows so that
  `Cattle.Cow` can register via `{:via, Registry, {Cattle.CattleRegistry, id}}`.
  """

  use Supervisor

  @doc "Starts the Cattle registry supervisor."
  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    children = [
      {Registry, keys: :unique, name: Cattle.CattleRegistry}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
