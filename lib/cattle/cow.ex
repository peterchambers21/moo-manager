# Cow module represents an individual cow as a GenServer process
# Tracks location, health, weight history, and feeding logs

defmodule Cattle.Cow do
  @moduledoc """
  A `GenServer` that models a single cow.

  ## State shape

    * `:id` — unique identifier used to register the process via `Registry`
    * `:age` — cow age (e.g. years)
    * `:health` — current health status (string/atom)
    * `:location` — current location tag/identifier
    * `:weights` — `[{Date.t(), number()}]`, newest-first
    * `:feed_log` — `[{Date.t(), feed_type, amount}]`, newest-first
    * `:health_log` — `[{Date.t(), status}]`, newest-first

  On init, the logs (`:weights`, `:feed_log`, `:health_log`) are ensured to exist (default `[]`).
  """

  use GenServer

  @type id :: term()
  @type weight_entry :: {Date.t(), number()}
  @type feed_entry :: {Date.t(), term(), number()}
  @type health_entry :: {Date.t(), term()}
  @type state :: %{
          required(:id) => id,
          required(:age) => non_neg_integer(),
          required(:health) => term(),
          required(:location) => term(),
          optional(:weights) => [weight_entry()],
          optional(:feed_log) => [feed_entry()],
          optional(:health_log) => [health_entry()]
        }

  ## Public API

  @doc """
  Starts a cow process registered by its `:id`.

  The given `state` map **must** include `:id`. Other keys like `:age`, `:health`,
  and `:location` are typically provided at startup.

  ### Examples

      iex> {:ok, _pid} =
      ...>   Cattle.Cow.start_link(%{id: "bessie", age: 3, health: :ok, location: :north})
  """
  @spec start_link(state()) :: GenServer.on_start()
  def start_link(%{id: id} = state) do
    GenServer.start_link(__MODULE__, state, name: via_tuple(id))
  end

  @doc "Returns the full state for the cow identified by `id`."
  @spec get_info(id()) :: state()
  def get_info(id), do: GenServer.call(via_tuple(id), :get_info)

  @doc "Updates the cow's `:location`."
  @spec update_location(id(), term()) :: :ok
  def update_location(id, new_location),
    do: GenServer.cast(via_tuple(id), {:update_location, new_location})

  @doc "Updates the cow's health status and prepends an entry to `:health_log` for today."
  @spec update_health(id(), term()) :: :ok
  def update_health(id, status), do: GenServer.cast(via_tuple(id), {:update_health, status})

  @doc "Records a `weight` (number) for today; prepends `{Date.utc_today(), weight}` to `:weights`."
  @spec record_weight(id(), number()) :: :ok
  def record_weight(id, weight), do: GenServer.cast(via_tuple(id), {:record_weight, weight})

  @doc "Returns the `:weights` list (newest-first)."
  @spec get_weights(id()) :: [weight_entry()]
  def get_weights(id), do: GenServer.call(via_tuple(id), :get_weights)

  @doc """
  Returns the arithmetic mean of all recorded weights, or `0.0` if none.

  This is a simple average across entries (no time-based weighting).
  """
  @spec get_average_weight(id()) :: float()
  def get_average_weight(id), do: GenServer.call(via_tuple(id), :average_weight)

  @doc "Prepends a feed log entry `{Date.utc_today(), feed_type, amount}`."
  @spec feed_cow(id(), term(), number()) :: :ok
  def feed_cow(id, feed_type, amount),
    do: GenServer.cast(via_tuple(id), {:feed, feed_type, amount})

  @doc "Returns the `:health_log` list (newest-first)."
  @spec get_health_log(id()) :: [health_entry()]
  def get_health_log(id), do: GenServer.call(via_tuple(id), :get_health_log)

  @doc """
  Returns a daily growth rate (kg/day) computed from two earliest chronological
  weight entries when available; otherwise `0.0`.

  Note: This uses the first two **oldest** entries (not first vs. latest).
  """
  @spec get_growth_rate(id()) :: float()
  def get_growth_rate(id), do: GenServer.call(via_tuple(id), :get_growth_rate)

  ## GenServer callbacks

  @impl true
  def init(state) do
    state =
      state
      |> Map.put(:weights, Map.get(state, :weights, []))
      |> Map.put(:feed_log, Map.get(state, :feed_log, []))
      |> Map.put(:health_log, Map.get(state, :health_log, []))

    {:ok, state}
  end

  @impl true
  def handle_call(:get_info, _from, state), do: {:reply, state, state}

  @impl true
  def handle_call(:get_weights, _from, %{weights: weights} = state), do: {:reply, weights, state}

  @impl true
  def handle_call(:get_health_log, _from, %{health_log: health_log} = state),
    do: {:reply, health_log, state}

  @impl true
  def handle_call(:average_weight, _from, %{weights: []} = state), do: {:reply, 0.0, state}

  @impl true
  def handle_call(:average_weight, _from, %{weights: weights} = state) do
    weights_only = Enum.map(weights, fn {_, w} -> w end)
    avg_weight = Enum.sum(weights_only) / length(weights_only)
    {:reply, avg_weight, state}
  end

  @impl true
  def handle_call(:get_growth_rate, _from, %{weights: weights} = state) do
    growth_rate =
      case Enum.reverse(weights) do
        [{start_date, start_weight}, {end_date, end_weight} | _] ->
          days = Date.diff(end_date, start_date)
          if days > 0, do: (end_weight - start_weight) / days, else: 0.0

        _ ->
          0.0
      end

    {:reply, growth_rate, state}
  end

  @impl true
  def handle_cast({:update_location, new_location}, state),
    do: {:noreply, %{state | location: new_location}}

  @impl true
  def handle_cast({:update_health, status}, state) do
    health_log = [{Date.utc_today(), status} | state.health_log]
    {:noreply, %{state | health: status, health_log: health_log}}
  end

  @impl true
  def handle_cast({:record_weight, weight}, %{weights: weights} = state) do
    new_entry = {Date.utc_today(), weight}
    {:noreply, %{state | weights: [new_entry | weights]}}
  end

  @impl true
  def handle_cast({:feed, feed_type, amount}, state) do
    feed_log = [{Date.utc_today(), feed_type, amount} | Map.get(state, :feed_log)]
    {:noreply, %{state | feed_log: feed_log}}
  end

  @doc """
  Provides a unique child spec so many cows can run under `Cattle.CowSupervisor`.
  """
  @spec child_spec(map()) :: Supervisor.child_spec()
  def child_spec(%{id: id} = state) do
    %{
      id: {:cow, id},
      start: {__MODULE__, :start_link, [state]},
      restart: :transient,
      shutdown: 5_000,
      type: :worker
    }
  end

  @doc """
  Returns the `Registry` via-tuple used to register/name a cow process by `id`.
  """
  @spec via_tuple(id()) :: {:via, Registry, {module(), id()}}
  def via_tuple(id), do: {:via, Registry, {Cattle.CattleRegistry, id}}
end
