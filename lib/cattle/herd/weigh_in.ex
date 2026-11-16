defmodule Cattle.Herd.WeighIn do
  @moduledoc "One weight measurement (in pounds) for an animal on a given date."

  use Ecto.Schema
  import Ecto.Changeset

  schema "weigh_ins" do
    field :weighed_on, :date
    field :weight_lb, :decimal
    field :notes, :string

    belongs_to :animal, Cattle.Herd.Animal

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a weigh-in changeset. When `arrival_date` is given, the weigh-in can't
  be dated before it.
  """
  def changeset(weigh_in, attrs, arrival_date \\ nil) do
    weigh_in
    |> cast(attrs, [:weighed_on, :weight_lb, :notes])
    |> validate_required([:animal_id, :weighed_on, :weight_lb])
    |> validate_number(:weight_lb, greater_than: 0, less_than: 100_000)
    |> update_change(:weight_lb, &Decimal.round(&1, 1))
    |> validate_on_or_after_arrival(arrival_date)
    |> foreign_key_constraint(:animal_id)
    |> check_constraint(:weight_lb, name: :weight_positive, message: "must be greater than 0")
  end

  defp validate_on_or_after_arrival(changeset, nil), do: changeset

  defp validate_on_or_after_arrival(changeset, arrival_date) do
    validate_change(changeset, :weighed_on, fn :weighed_on, date ->
      if Date.compare(date, arrival_date) == :lt,
        do: [weighed_on: "can't be before arrival date"],
        else: []
    end)
  end
end
