ExUnit.start()

defmodule Cattle.TestHelpers do
  @moduledoc false

  @doc "Stops every cow under `Cattle.CowSupervisor` so each test starts clean."
  def stop_all_cows do
    for {_, pid, _, _} <- DynamicSupervisor.which_children(Cattle.CowSupervisor) do
      DynamicSupervisor.terminate_child(Cattle.CowSupervisor, pid)
    end

    :ok
  end
end
