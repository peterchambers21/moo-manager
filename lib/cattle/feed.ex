defmodule Cattle.Feed do
  @moduledoc """
  Feed deliveries, recorded per pen. Amounts are in pounds (as fed).
  """

  import Ecto.Query

  alias Cattle.{Herd, Repo}
  alias Cattle.Herd.Pen
  alias Cattle.Feed.Feeding

  @doc """
  Records a feed delivery to a pen.

  Required: `:fed_on`, `:feed_type`, `:amount_lb`. Optional: `:notes`.
  """
  def record_feeding(%Pen{} = pen, attrs) do
    %Feeding{pen_id: pen.id} |> Feeding.changeset(attrs) |> Repo.insert()
  end

  @doc "Changeset for a feeding form."
  def change_feeding(%Pen{} = pen, attrs \\ %{}) do
    Feeding.changeset(%Feeding{pen_id: pen.id}, attrs)
  end

  @doc "Lists a pen's feedings between two dates (inclusive), newest first."
  def list_feedings(%Pen{} = pen, %Date{} = first_day, %Date{} = last_day) do
    pen
    |> feedings_between(first_day, last_day)
    |> order_by([f], desc: f.fed_on, desc: f.id)
    |> Repo.all()
  end

  @doc "Total lb fed to a pen between two dates (inclusive). Zero if none."
  def total_fed(%Pen{} = pen, %Date{} = first_day, %Date{} = last_day) do
    total =
      pen
      |> feedings_between(first_day, last_day)
      |> select([f], sum(f.amount_lb))
      |> Repo.one()

    Decimal.round(total || Decimal.new(0), 1)
  end

  @doc """
  Average lb fed per head per day over a date range (inclusive), rounded to 0.01.

  Uses the pen's **current** head count, so it's only accurate if the pen's
  population didn't change during the range. `nil` if the pen is empty.
  """
  def feed_per_head_per_day(%Pen{} = pen, %Date{} = first_day, %Date{} = last_day) do
    head_count = Herd.head_count(pen)
    days = Date.diff(last_day, first_day) + 1

    if head_count > 0 and days > 0 do
      pen
      |> total_fed(first_day, last_day)
      |> Decimal.div(head_count * days)
      |> Decimal.round(2)
    end
  end

  defp feedings_between(%Pen{id: pen_id}, first_day, last_day) do
    from(f in Feeding,
      where: f.pen_id == ^pen_id and f.fed_on >= ^first_day and f.fed_on <= ^last_day
    )
  end
end
