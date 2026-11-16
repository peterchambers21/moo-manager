defmodule CattleWeb.Format do
  @moduledoc "Display helpers for weights, gains, dates and labels."

  @doc "A weight in lb to one decimal place, or a dash if unknown."
  def lb(nil), do: "—"
  def lb(%Decimal{} = d), do: "#{Decimal.round(d, 1)} lb"

  @doc "Average daily gain to two decimal places, or a dash if unknown."
  def adg(nil), do: "—"
  def adg(%Decimal{} = d), do: "#{Decimal.round(d, 2)} lb/day"

  @doc "A date as YYYY-MM-DD, or a dash."
  def date(nil), do: "—"
  def date(%Date{} = d), do: Date.to_iso8601(d)

  @doc "An enum atom (or nil) as a capitalized label."
  def label(nil), do: "—"
  def label(atom) when is_atom(atom), do: atom |> Atom.to_string() |> String.capitalize()

  @doc "Head count against capacity, e.g. `12 / 40` or `12` when unlimited."
  def head(count, nil), do: "#{count}"
  def head(count, capacity), do: "#{count} / #{capacity}"

  @doc "daisyUI badge class for an animal status."
  def status_badge(:active), do: "badge badge-success badge-soft"
  def status_badge(:shipped), do: "badge badge-info badge-soft"
  def status_badge(:dead), do: "badge badge-neutral badge-soft"
end
