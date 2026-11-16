defmodule Cattle.Health do
  @moduledoc """
  Health records (observations, treatments, vaccinations) and drug withdrawal.

  A treatment's `withdrawal_until` is the last day of its withdrawal period:
  the animal may ship on the following day at the earliest.
  """

  import Ecto.Query

  alias Cattle.Repo
  alias Cattle.Herd.Animal
  alias Cattle.Health.HealthEvent

  @doc """
  Records a health event for an animal.

  Required: `:occurred_on`, `:kind` (`:observation | :treatment | :vaccination`),
  and `:description`. Optional: `:product`, `:dose`, `:withdrawal_until`, `:notes`.
  """
  def record_event(%Animal{} = animal, attrs) do
    %HealthEvent{animal_id: animal.id}
    |> HealthEvent.changeset(attrs, animal.arrival_date)
    |> Repo.insert()
  end

  @doc "Changeset for a health event form."
  def change_event(%Animal{} = animal, attrs \\ %{}) do
    HealthEvent.changeset(%HealthEvent{animal_id: animal.id}, attrs, animal.arrival_date)
  end

  @doc "Lists an animal's health events, newest first."
  def list_events(%Animal{id: id}) do
    Repo.all(
      from(e in HealthEvent,
        where: e.animal_id == ^id,
        order_by: [desc: e.occurred_on, desc: e.id]
      )
    )
  end

  @doc "True if any withdrawal period for the animal covers `date` (default today)."
  def under_withdrawal?(%Animal{id: id}, date \\ Date.utc_today()) do
    Repo.exists?(
      from(e in HealthEvent,
        where: e.animal_id == ^id and e.withdrawal_until >= ^date
      )
    )
  end

  @doc """
  Active animals still under withdrawal on `date` (default today), as
  `{animal, last_withdrawal_day}` tuples, soonest-to-clear first.
  """
  def animals_under_withdrawal(date \\ Date.utc_today()) do
    Repo.all(
      from(a in Animal,
        join: e in HealthEvent,
        on: e.animal_id == a.id,
        where: a.status == :active and e.withdrawal_until >= ^date,
        group_by: a.id,
        order_by: [asc: max(e.withdrawal_until), asc: a.tag],
        select: {a, max(e.withdrawal_until)}
      )
    )
  end
end
