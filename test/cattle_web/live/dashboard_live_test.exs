defmodule CattleWeb.DashboardLiveTest do
  use CattleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Cattle.Fixtures

  alias Cattle.Health

  test "renders with no data", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Head on feed"
    assert html =~ "No pens yet"
  end

  test "summarizes pens and animals under withdrawal", %{conn: conn} do
    pen = pen_fixture(%{name: "East", capacity: 10})
    animal = animal_fixture(%{tag: "W1", pen_id: pen.id, arrival_weight_lb: 600})

    {:ok, _} =
      Health.record_event(animal, %{
        occurred_on: Date.utc_today(),
        kind: :treatment,
        description: "Antibiotic",
        withdrawal_until: Date.add(Date.utc_today(), 7)
      })

    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "East"
    assert html =~ "1 / 10"
    assert html =~ "600.0 lb"
    assert html =~ "W1"
    assert html =~ "Drug withdrawal"
  end
end
