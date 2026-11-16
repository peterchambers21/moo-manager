defmodule Cattle.Herd.Pen do
  @moduledoc "A pen that holds animals and receives feed deliveries."

  use Ecto.Schema
  import Ecto.Changeset

  schema "pens" do
    field :name, :string
    # Maximum head count; `nil` means unlimited.
    field :capacity, :integer
    field :notes, :string

    has_many :animals, Cattle.Herd.Animal
    has_many :feedings, Cattle.Feed.Feeding

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(pen, attrs) do
    pen
    |> cast(attrs, [:name, :capacity, :notes])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> validate_number(:capacity, greater_than: 0)
    |> unique_constraint(:name)
    |> check_constraint(:capacity, name: :capacity_positive, message: "must be greater than 0")
  end
end
