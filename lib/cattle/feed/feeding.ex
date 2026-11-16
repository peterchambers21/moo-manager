defmodule Cattle.Feed.Feeding do
  @moduledoc "A feed delivery to a pen: what was fed, how much (lb), and when."

  use Ecto.Schema
  import Ecto.Changeset

  schema "feedings" do
    field :fed_on, :date
    field :feed_type, :string
    field :amount_lb, :decimal
    field :notes, :string

    belongs_to :pen, Cattle.Herd.Pen

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(feeding, attrs) do
    feeding
    |> cast(attrs, [:fed_on, :feed_type, :amount_lb, :notes])
    |> validate_required([:pen_id, :fed_on, :feed_type, :amount_lb])
    |> validate_number(:amount_lb, greater_than: 0, less_than: 100_000_000)
    |> update_change(:amount_lb, &Decimal.round(&1, 1))
    |> foreign_key_constraint(:pen_id)
    |> check_constraint(:amount_lb, name: :amount_positive, message: "must be greater than 0")
  end
end
