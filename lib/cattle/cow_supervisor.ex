defmodule Cattle.CowSupervisor do
  use DynamicSupervisor

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Start a cow under this supervisor
  def start_cow(attrs) do
    DynamicSupervisor.start_child(__MODULE__, {Cattle.Cow, attrs})
  end
end
