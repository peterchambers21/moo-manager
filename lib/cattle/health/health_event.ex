defmodule Cattle.Health.HealthEvent do
  @moduledoc """
  A health record for an animal: an observation, a treatment, or a vaccination.

  `withdrawal_until` is the **last day** of a drug withdrawal period. The
  animal must not be shipped on or before that date.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "health_events" do
    field :occurred_on, :date
    field :kind, Ecto.Enum, values: [:observation, :treatment, :vaccination]
    field :description, :string
    field :product, :string
    field :dose, :string
    field :withdrawal_until, :date
    field :notes, :string

    belongs_to :animal, Cattle.Herd.Animal

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a health event changeset. When `arrival_date` is given, the event
  can't be dated before it.
  """
  def changeset(event, attrs, arrival_date \\ nil) do
    event
    |> cast(attrs, [:occurred_on, :kind, :description, :product, :dose, :withdrawal_until, :notes])
    |> validate_required([:animal_id, :occurred_on, :kind, :description])
    |> validate_dates(arrival_date)
    |> foreign_key_constraint(:animal_id)
    |> check_constraint(:withdrawal_until, name: :withdrawal_after_event)
  end

  defp validate_dates(changeset, arrival_date) do
    occurred_on = get_field(changeset, :occurred_on)
    withdrawal_until = get_field(changeset, :withdrawal_until)

    changeset
    |> then(fn cs ->
      if occurred_on && arrival_date && Date.compare(occurred_on, arrival_date) == :lt,
        do: add_error(cs, :occurred_on, "can't be before arrival date"),
        else: cs
    end)
    |> then(fn cs ->
      if occurred_on && withdrawal_until && Date.compare(withdrawal_until, occurred_on) == :lt,
        do: add_error(cs, :withdrawal_until, "can't be before the event date"),
        else: cs
    end)
  end
end
