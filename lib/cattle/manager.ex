# CattleManager handles interactions with multiple cows

defmodule CattleManager do
  @moduledoc """
  Convenience API for working with many cows at once.

  This module is a **facade** over individual `Cattle.Cow` processes and provides
  herd-level operations (e.g., averages, parallel queries). It does **not** hold
  its own state.

  ## Concurrency

  Herd queries use `Task.Supervisor.async_stream_nolink/4` (under
  `Cattle.TaskSupervisor`) so calls to many cows happen in **parallel**.
  A slow, crashed, or missing cow won't stall or crash the entire
  computation: its result is skipped.

  ### Defaults
    * `max_concurrency`: `System.schedulers_online/0`
    * `timeout`: 2_000 ms per task (not the GenServer’s internal timeout)
    * `on_timeout`: `:kill_task` (skip the result)

  You can adjust these by editing `@default_task_opts`.
  """

  alias Cattle.Cow

  @default_task_opts [
    max_concurrency: System.schedulers_online(),
    timeout: 2_000,
    on_timeout: :kill_task
  ]

  # ---------- helpers (private) ----------

  # Parallel map with sensible defaults; yields only successful results.
  defp pmap(enumerable, fun, opts \\ []) do
    enumerable
    |> then(
      &Task.Supervisor.async_stream_nolink(
        Cattle.TaskSupervisor,
        &1,
        fun,
        Keyword.merge(@default_task_opts, opts)
      )
    )
    |> Stream.filter(&match?({:ok, _}, &1))
    |> Stream.map(fn {:ok, v} -> v end)
  end

  defp avg([]), do: 0.0
  defp avg(list), do: Enum.sum(list) / length(list)

  # ---------- single-cow wrappers ----------

  @doc """
  Starts a new cow process under `Cattle.CowSupervisor`.

  The `id` is used to register the process in `Cattle.CattleRegistry`, so it
  must be unique; starting a second cow with the same id returns
  `{:error, {:already_started, pid}}`.

  Returns a `DynamicSupervisor.on_start_child()` tuple.
  """
  @spec start_cow(term(), non_neg_integer(), term(), term()) ::
          DynamicSupervisor.on_start_child()
  def start_cow(id, age, health, location) do
    Cattle.CowSupervisor.start_cow(%{id: id, age: age, health: health, location: location})
  end

  @doc "Returns the full state for a cow identified by `id`."
  @spec get_cow_info(term()) :: map()
  def get_cow_info(id), do: Cow.get_info(id)

  @doc "Updates the cow's location to `new_location`."
  @spec move_cow(term(), term()) :: :ok
  def move_cow(id, new_location), do: Cow.update_location(id, new_location)

  @doc "Sets the cow's health status and logs the change for today."
  @spec set_cow_health(term(), term()) :: :ok
  def set_cow_health(id, status), do: Cow.update_health(id, status)

  @doc "Records a new `weight` for today for the given cow."
  @spec record_cow_weight(term(), number()) :: :ok
  def record_cow_weight(id, weight), do: Cow.record_weight(id, weight)

  @doc "Returns the list of weight entries (newest-first) for the cow."
  @spec get_cow_weights(term()) :: [{Date.t(), number()}]
  def get_cow_weights(id), do: Cow.get_weights(id)

  @doc """
  Returns the cow's average weight (simple mean across all entries).
  Returns `0.0` if no weights are recorded.
  """
  @spec get_cow_average_weight(term()) :: float()
  def get_cow_average_weight(id), do: Cow.get_average_weight(id)

  @doc "Appends a feed log entry `{Date.t(), feed_type, amount}` for the cow."
  @spec feed_cow(term(), term(), number()) :: :ok
  def feed_cow(id, feed_type, amount), do: Cow.feed_cow(id, feed_type, amount)

  @doc "Returns the cow's health history (newest-first)."
  @spec get_cow_health_log(term()) :: [{Date.t(), term()}]
  def get_cow_health_log(id), do: Cow.get_health_log(id)

  @doc """
  Returns the cow's growth rate (e.g., kg/day). See `Cattle.Cow.get_growth_rate/1`
  for the exact calculation used.
  """
  @spec get_cow_growth_rate(term()) :: float()
  def get_cow_growth_rate(id), do: Cow.get_growth_rate(id)

  # ---------- herd-level (parallelized) ----------

  @doc """
  Lists all registered cow ids from `Cattle.CattleRegistry`.

  This reads ids directly from the registry; it does not contact each cow.
  """
  @spec list_cows() :: [term()]
  def list_cows do
    Registry.select(Cattle.CattleRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc """
  Returns the ids of cows whose current `:location` equals `location`.

  This fetches info from all cows **in parallel** and filters by location.
  Cows that fail or time out are ignored.
  """
  @spec get_cows_by_location(term()) :: [term()]
  def get_cows_by_location(location) do
    list_cows()
    |> pmap(fn id -> {id, Cow.get_info(id)} end)
    |> Enum.reduce([], fn
      {id, %{location: ^location}}, acc -> [id | acc]
      _, acc -> acc
    end)
    |> Enum.reverse()
  end

  @doc """
  Returns the herd-wide mean of each cow's average weight (ignores 0.0s).

  This is an **average of per-cow averages** (not weighted by number of
  measurements). Queries each cow **in parallel**.
  """
  @spec herd_average_weight() :: float()
  def herd_average_weight do
    list_cows()
    |> pmap(&get_cow_average_weight/1)
    |> Enum.reject(&(&1 == 0.0))
    |> avg()
  end

  @doc """
  Returns the mean of per-cow average weights for cows at `location` (ignores 0.0s).

  Calls are issued **in parallel** to the cows filtered by location.
  """
  @spec location_average_weight(term()) :: float()
  def location_average_weight(location) do
    get_cows_by_location(location)
    |> pmap(&get_cow_average_weight/1)
    |> Enum.reject(&(&1 == 0.0))
    |> avg()
  end

  @doc """
  Returns the mean growth rate across the herd (ignores 0.0s), computed **in parallel**.
  """
  @spec average_growth_rate() :: float()
  def average_growth_rate do
    list_cows()
    |> pmap(&get_cow_growth_rate/1)
    |> Enum.reject(&(&1 == 0.0))
    |> avg()
  end
end
