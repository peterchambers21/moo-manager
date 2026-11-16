defmodule Cattle.Fixtures do
  @moduledoc "Builders for test data."

  alias Cattle.Herd

  def pen_fixture(attrs \\ %{}) do
    {:ok, pen} =
      attrs
      |> Enum.into(%{name: "Pen #{System.unique_integer([:positive])}"})
      |> Herd.create_pen()

    pen
  end

  def animal_fixture(attrs \\ %{}) do
    {:ok, animal} =
      attrs
      |> Enum.into(%{tag: "T#{System.unique_integer([:positive])}", arrival_date: ~D[2025-01-01]})
      |> Herd.register_animal()

    animal
  end
end
