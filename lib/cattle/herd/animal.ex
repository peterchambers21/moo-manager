defmodule Cattle.Herd.Animal do
  @moduledoc """
  An individual animal, identified by its ear `tag`.

  `status` is `:active` while the animal is on the feedlot, and `:shipped` or
  `:dead` once it has left, in which case `departure_date` is set.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @sexes [:steer, :heifer, :bull, :cow]
  @statuses [:active, :shipped, :dead]

  schema "animals" do
    field :tag, :string
    field :breed, :string
    field :sex, Ecto.Enum, values: @sexes
    field :birth_date, :date
    field :arrival_date, :date
    field :source, :string
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :departure_date, :date
    field :notes, :string

    # Only used when registering: recorded as the first weigh-in.
    field :arrival_weight_lb, :decimal, virtual: true

    belongs_to :pen, Cattle.Herd.Pen
    has_many :weigh_ins, Cattle.Herd.WeighIn
    has_many :health_events, Cattle.Health.HealthEvent

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for registering a new animal, including an optional arrival weight."
  def registration_changeset(animal, attrs) do
    animal
    |> cast(attrs, [:arrival_weight_lb])
    |> validate_number(:arrival_weight_lb, greater_than: 0)
    |> changeset(attrs)
  end

  @doc "Changeset for an animal's details and pen. Status changes use `departure_changeset/3`."
  def changeset(animal, attrs) do
    animal
    |> cast(attrs, [:tag, :breed, :sex, :birth_date, :arrival_date, :source, :notes, :pen_id])
    |> update_change(:tag, &String.trim/1)
    |> validate_required([:tag, :arrival_date])
    |> validate_length(:tag, max: 50)
    |> validate_not_after(:birth_date, :arrival_date, "can't be after arrival date")
    |> unique_constraint(:tag)
    |> foreign_key_constraint(:pen_id)
    |> check_constraint(:birth_date, name: :birth_before_arrival)
  end

  @doc "Marks an active animal as `:shipped` or `:dead` on `date`."
  def departure_changeset(animal, status, date) when status in [:shipped, :dead] do
    animal
    |> change(status: status, departure_date: date)
    |> validate_required([:departure_date])
    |> validate_not_after(:arrival_date, :departure_date, "can't be before arrival date")
    |> check_constraint(:departure_date, name: :departure_after_arrival)
  end

  # Adds an error to `field` when its date is after the date in `other`.
  defp validate_not_after(changeset, field, other, message) do
    earlier = get_field(changeset, field)
    later = get_field(changeset, other)

    if earlier && later && Date.compare(earlier, later) == :gt do
      error_field = if field == :arrival_date, do: other, else: field
      add_error(changeset, error_field, message)
    else
      changeset
    end
  end
end
