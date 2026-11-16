defmodule Cattle.Herd do
  @moduledoc """
  Pens, animals, and weigh-ins, plus weight and gain metrics.

  All weights are in pounds. Metrics return `Decimal`s: average weights are
  rounded to 0.1 lb and average daily gain (ADG) to 0.01 lb/day. Metrics with
  no data to work from return `nil`.

  Herd and pen metrics only count **active** animals (not shipped or dead).
  """

  import Ecto.Query

  alias Ecto.{Changeset, Multi}
  alias Cattle.{Health, Repo}
  alias Cattle.Herd.{Animal, Pen, WeighIn}
  alias Cattle.Feed.Feeding

  ## Pens

  @doc "Lists all pens, ordered by name."
  def list_pens, do: Repo.all(from(p in Pen, order_by: p.name))

  def get_pen!(id), do: Repo.get!(Pen, id)

  def get_pen_by_name(name), do: Repo.get_by(Pen, name: name)

  def create_pen(attrs), do: %Pen{} |> Pen.changeset(attrs) |> Repo.insert()

  def update_pen(%Pen{} = pen, attrs), do: pen |> Pen.changeset(attrs) |> Repo.update()

  @doc "Changeset for a pen form."
  def change_pen(%Pen{} = pen, attrs \\ %{}), do: Pen.changeset(pen, attrs)

  @doc """
  Deletes a pen. Fails with an error changeset if any animal (current or past)
  or any feeding references it, so history is never lost.
  """
  def delete_pen(%Pen{id: id} = pen) do
    # Checked here rather than via `no_assoc_constraint/2` because SQLite
    # doesn't name the foreign key that failed, so Ecto can't map it.
    pen
    |> Changeset.change()
    |> refuse_if_referenced(:animals, from(a in Animal, where: a.pen_id == ^id))
    |> refuse_if_referenced(:feedings, from(f in Feeding, where: f.pen_id == ^id))
    |> Repo.delete()
  end

  defp refuse_if_referenced(changeset, assoc, query) do
    if Repo.exists?(query),
      do: Changeset.add_error(changeset, assoc, "are still associated with this entry"),
      else: changeset
  end

  @doc "Number of active animals currently in the pen."
  def head_count(%Pen{id: id}), do: head_count(id)
  def head_count(pen_id), do: pen_id |> active_in_pen() |> Repo.aggregate(:count)

  ## Animals

  @doc """
  Registers a new animal.

  Required: `:tag` (unique) and `:arrival_date`. Optional: `:breed`, `:sex`
  (`:steer | :heifer | :bull | :cow`), `:birth_date`, `:source`, `:notes`,
  `:pen_id`, and `:arrival_weight_lb`, which is saved as the first weigh-in
  on the arrival date.

  Fails if the chosen pen is at capacity.
  """
  def register_animal(attrs) do
    changeset = %Animal{} |> Animal.registration_changeset(attrs) |> check_capacity()

    Multi.new()
    |> Multi.insert(:animal, changeset)
    |> Multi.run(:arrival_weigh_in, fn repo, %{animal: animal} ->
      case animal.arrival_weight_lb do
        nil ->
          {:ok, nil}

        weight ->
          %WeighIn{animal_id: animal.id}
          |> WeighIn.changeset(%{weight_lb: weight, weighed_on: animal.arrival_date})
          |> repo.insert()
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{animal: animal}} -> {:ok, animal}
      {:error, _step, changeset, _} -> {:error, changeset}
    end
  end

  @doc "Changeset for an animal form: registration for a new animal, details otherwise."
  def change_animal(animal, attrs \\ %{})

  def change_animal(%Animal{id: nil} = animal, attrs),
    do: Animal.registration_changeset(animal, attrs)

  def change_animal(%Animal{} = animal, attrs), do: Animal.changeset(animal, attrs)

  def get_animal!(id), do: Repo.get!(Animal, id)

  def get_animal_by_tag(tag), do: Repo.get_by(Animal, tag: tag)

  @doc """
  Lists animals ordered by tag.

  Options:
    * `:status` — `:active` (default), `:shipped`, `:dead`, or `:all`
    * `:pen` — only animals in this `%Pen{}`
  """
  def list_animals(opts \\ []) do
    query = from(a in Animal, order_by: a.tag)

    query =
      case Keyword.get(opts, :status, :active) do
        :all -> query
        status -> where(query, [a], a.status == ^status)
      end

    query =
      case Keyword.fetch(opts, :pen) do
        {:ok, %Pen{id: pen_id}} -> where(query, [a], a.pen_id == ^pen_id)
        :error -> query
      end

    Repo.all(query)
  end

  @doc "Updates an animal's details. Fails if moved into a full pen."
  def update_animal(%Animal{} = animal, attrs) do
    animal |> Animal.changeset(attrs) |> check_capacity() |> Repo.update()
  end

  @doc """
  Moves an active animal to `pen`, or out of any pen with `nil`.

  Returns `{:error, :not_active}` for an animal that has left the feedlot,
  or an error changeset if the pen is full.
  """
  def move_animal(%Animal{status: :active} = animal, pen) do
    pen_id = if pen, do: pen.id
    update_animal(animal, %{pen_id: pen_id})
  end

  def move_animal(%Animal{}, _pen), do: {:error, :not_active}

  @doc """
  Marks an active animal as shipped on `shipped_on`.

  Returns `{:error, :under_withdrawal}` if a drug withdrawal period covers
  that date (see `Cattle.Health.under_withdrawal?/2`), or
  `{:error, :not_active}` if the animal has already left.
  """
  def ship_animal(%Animal{} = animal, shipped_on \\ Date.utc_today()) do
    if animal.status == :active and Health.under_withdrawal?(animal, shipped_on),
      do: {:error, :under_withdrawal},
      else: depart(animal, :shipped, shipped_on)
  end

  @doc "Marks an active animal as dead on `died_on`. Record the cause with `Cattle.Health`."
  def record_death(%Animal{} = animal, died_on \\ Date.utc_today()),
    do: depart(animal, :dead, died_on)

  defp depart(%Animal{status: :active} = animal, status, date) do
    animal |> Animal.departure_changeset(status, date) |> Repo.update()
  end

  defp depart(%Animal{}, _status, _date), do: {:error, :not_active}

  # Adds an error if the changeset moves the animal into a pen that doesn't
  # exist (checked here since SQLite foreign key errors are unnamed) or is full.
  defp check_capacity(changeset) do
    case Changeset.get_change(changeset, :pen_id) do
      nil ->
        changeset

      pen_id ->
        case Repo.get(Pen, pen_id) do
          nil ->
            Changeset.add_error(changeset, :pen_id, "does not exist")

          %Pen{capacity: capacity} when is_integer(capacity) ->
            if head_count(pen_id) >= capacity,
              do: Changeset.add_error(changeset, :pen_id, "pen is full"),
              else: changeset

          %Pen{} ->
            changeset
        end
    end
  end

  ## Weigh-ins

  @doc "Records a weight in lb for `weighed_on` (default today). Can't be before arrival."
  def record_weight(%Animal{} = animal, weight_lb, weighed_on \\ Date.utc_today()) do
    %WeighIn{animal_id: animal.id}
    |> WeighIn.changeset(%{weight_lb: weight_lb, weighed_on: weighed_on}, animal.arrival_date)
    |> Repo.insert()
  end

  @doc "Changeset for a weigh-in form."
  def change_weigh_in(%Animal{} = animal, attrs \\ %{}) do
    WeighIn.changeset(%WeighIn{animal_id: animal.id}, attrs, animal.arrival_date)
  end

  @doc "Lists an animal's weigh-ins, newest first."
  def list_weigh_ins(%Animal{id: id}) do
    Repo.all(
      from(w in WeighIn,
        where: w.animal_id == ^id,
        order_by: [desc: w.weighed_on, desc: w.id]
      )
    )
  end

  @doc "The animal's most recent weight in lb, or `nil` if never weighed."
  def latest_weight(%Animal{id: id}) do
    Repo.one(
      from(w in WeighIn,
        where: w.animal_id == ^id,
        order_by: [desc: w.weighed_on, desc: w.id],
        limit: 1,
        select: w.weight_lb
      )
    )
  end

  ## Metrics

  @doc """
  Average daily gain (lb/day) from the animal's first weigh-in to its latest.
  `nil` with fewer than two weigh-ins, or if they are all on the same day.
  """
  def average_daily_gain(%Animal{id: id}) do
    from(a in Animal, where: a.id == ^id) |> daily_gains() |> mean(2)
  end

  @doc "Mean of each active animal's latest weight in the pen."
  def pen_average_weight(%Pen{id: id}), do: id |> active_in_pen() |> latest_weights() |> mean(1)

  @doc "Mean of each active animal's latest weight across the feedlot."
  def herd_average_weight, do: active() |> latest_weights() |> mean(1)

  @doc "Mean ADG of the pen's active animals that have a gain to report."
  def pen_average_daily_gain(%Pen{id: id}), do: id |> active_in_pen() |> daily_gains() |> mean(2)

  @doc "Mean ADG of all active animals that have a gain to report."
  def herd_average_daily_gain, do: active() |> daily_gains() |> mean(2)

  defp active, do: from(a in Animal, where: a.status == :active)

  defp active_in_pen(pen_id), do: where(active(), [a], a.pen_id == ^pen_id)

  # For each animal in the query that has weigh-ins: {first, latest} weigh-in.
  defp weigh_in_ranges(animals) do
    ids = select(animals, [a], a.id)

    from(w in WeighIn,
      where: w.animal_id in subquery(ids),
      order_by: [w.animal_id, w.weighed_on, w.id]
    )
    |> Repo.all()
    |> Enum.chunk_by(& &1.animal_id)
    |> Enum.map(&{hd(&1), List.last(&1)})
  end

  defp latest_weights(animals) do
    animals |> weigh_in_ranges() |> Enum.map(fn {_first, latest} -> latest.weight_lb end)
  end

  defp daily_gains(animals) do
    animals
    |> weigh_in_ranges()
    |> Enum.flat_map(fn {first, latest} ->
      case Date.diff(latest.weighed_on, first.weighed_on) do
        days when days > 0 -> [Decimal.div(Decimal.sub(latest.weight_lb, first.weight_lb), days)]
        _ -> []
      end
    end)
  end

  defp mean([], _places), do: nil

  defp mean(values, places) do
    values
    |> Enum.reduce(&Decimal.add/2)
    |> Decimal.div(length(values))
    |> Decimal.round(places)
  end
end
