defmodule CattleWeb.AnimalLiveTest do
  use CattleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Cattle.Fixtures

  alias Cattle.{Health, Herd}

  test "registers an animal with an arrival weight", %{conn: conn} do
    pen = pen_fixture(%{name: "Receiving"})
    {:ok, view, _html} = live(conn, ~p"/animals/new")

    {:ok, _view, html} =
      view
      |> form("#animal-form",
        animal: %{
          tag: "1042",
          sex: "steer",
          arrival_date: "2025-03-01",
          pen_id: pen.id,
          arrival_weight_lb: "550"
        }
      )
      |> render_submit()
      |> follow_redirect(conn)

    assert html =~ "Saved 1042."
    assert html =~ "550.0 lb"
    assert html =~ "Receiving"
  end

  test "shows registration errors", %{conn: conn} do
    animal_fixture(%{tag: "DUP"})
    {:ok, view, _html} = live(conn, ~p"/animals/new")

    html =
      view
      |> form("#animal-form", animal: %{tag: "DUP", arrival_date: "2025-03-01"})
      |> render_submit()

    assert html =~ "has already been taken"
  end

  test "lists and filters animals by status", %{conn: conn} do
    animal_fixture(%{tag: "ALIVE"})
    gone = animal_fixture(%{tag: "GONE"})
    {:ok, _} = Herd.ship_animal(gone, ~D[2025-02-01])

    {:ok, view, html} = live(conn, ~p"/animals")
    assert html =~ "ALIVE"
    refute html =~ "GONE"

    html = view |> form("#animal-filter", status: "shipped") |> render_change()
    assert_patch(view, ~p"/animals?status=shipped")
    assert html =~ "GONE"
    refute html =~ "ALIVE"
  end

  test "records a weigh-in and a health event", %{conn: conn} do
    animal = animal_fixture(%{arrival_date: ~D[2025-01-01], arrival_weight_lb: 500})
    {:ok, view, _html} = live(conn, ~p"/animals/#{animal}")

    html =
      view
      |> form("#weight-form", weigh_in: %{weighed_on: "2025-01-11", weight_lb: "530"})
      |> render_submit()

    assert html =~ "Recorded 530.0 lb."
    assert html =~ "3.00 lb/day"

    html =
      view
      |> form("#event-form",
        health_event: %{occurred_on: "2025-01-05", kind: "observation", description: "Limping"}
      )
      |> render_submit()

    assert html =~ "Limping"
    assert [_] = Health.list_events(animal)
  end

  test "shows a weigh-in dated before arrival as an error", %{conn: conn} do
    animal = animal_fixture(%{arrival_date: ~D[2025-01-10]})
    {:ok, view, _html} = live(conn, ~p"/animals/#{animal}")

    html =
      view
      |> form("#weight-form", weigh_in: %{weighed_on: "2025-01-01", weight_lb: "500"})
      |> render_submit()

    assert html =~ "can&#39;t be before arrival date"
  end

  test "moves an animal and refuses a full pen", %{conn: conn} do
    open = pen_fixture(%{name: "Open"})
    full = pen_fixture(%{name: "Full", capacity: 1})
    animal_fixture(%{pen_id: full.id})
    animal = animal_fixture()

    {:ok, view, _html} = live(conn, ~p"/animals/#{animal}")

    assert view |> form("#move-form", pen_id: open.id) |> render_submit() =~ "Moved to Open."
    assert view |> form("#move-form", pen_id: full.id) |> render_submit() =~ "pen is full"
    assert Herd.get_animal!(animal.id).pen_id == open.id
  end

  test "blocks shipping during withdrawal, then ships after", %{conn: conn} do
    animal = animal_fixture(%{tag: "RX", arrival_date: ~D[2025-01-01]})

    {:ok, _} =
      Health.record_event(animal, %{
        occurred_on: ~D[2025-01-05],
        kind: :treatment,
        description: "Antibiotic",
        withdrawal_until: ~D[2025-01-20]
      })

    {:ok, view, _html} = live(conn, ~p"/animals/#{animal}")

    html =
      view
      |> form("#depart-form", date: "2025-01-20")
      |> render_submit(%{kind: "ship"})

    assert html =~ "withdrawal period covers that date"
    assert Herd.get_animal!(animal.id).status == :active

    html =
      view
      |> form("#depart-form", date: "2025-01-21")
      |> render_submit(%{kind: "ship"})

    assert html =~ "RX shipped."
    assert Herd.get_animal!(animal.id).status == :shipped
    refute has_element?(view, "#depart-form")
  end
end
