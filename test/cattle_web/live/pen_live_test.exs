defmodule CattleWeb.PenLiveTest do
  use CattleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Cattle.Fixtures

  alias Cattle.{Feed, Herd}

  test "creates a pen, validating on change", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/pens/new")

    assert view |> form("#pen-form", pen: %{name: ""}) |> render_change() =~ "can&#39;t be blank"

    {:ok, _view, html} =
      view
      |> form("#pen-form", pen: %{name: "North 1", capacity: "40"})
      |> render_submit()
      |> follow_redirect(conn)

    assert html =~ "Saved North 1."
    assert html =~ "0 / 40"
  end

  test "edits a pen", %{conn: conn} do
    pen = pen_fixture(%{name: "Old"})
    {:ok, view, _html} = live(conn, ~p"/pens/#{pen}/edit")

    {:ok, _view, html} =
      view |> form("#pen-form", pen: %{name: "New"}) |> render_submit() |> follow_redirect(conn)

    assert html =~ "Saved New."
    assert Herd.get_pen!(pen.id).name == "New"
  end

  test "deletes an empty pen but refuses one with animals", %{conn: conn} do
    empty = pen_fixture(%{name: "Empty"})
    busy = pen_fixture(%{name: "Busy"})
    animal_fixture(%{pen_id: busy.id})

    {:ok, view, _html} = live(conn, ~p"/pens")

    assert view |> element("#pen-#{empty.id} a", "Delete") |> render_click() =~ "Deleted Empty."
    refute has_element?(view, "#pen-#{empty.id}")

    assert view |> element("#pen-#{busy.id} a", "Delete") |> render_click() =~
             "can&#39;t be deleted"

    assert has_element?(view, "#pen-#{busy.id}")
  end

  test "shows a pen's animals and records a feeding", %{conn: conn} do
    pen = pen_fixture(%{name: "South"})
    animal_fixture(%{tag: "A1", pen_id: pen.id})
    today = Date.utc_today()

    {:ok, view, html} = live(conn, ~p"/pens/#{pen}")
    assert html =~ "A1"

    html =
      view
      |> form("#feeding-form", feeding: %{fed_on: today, feed_type: "hay", amount_lb: "250"})
      |> render_submit()

    assert html =~ "Recorded 250.0 lb of hay."
    assert [%{feed_type: "hay"}] = Feed.list_feedings(pen, today, today)
  end

  test "shows feeding errors", %{conn: conn} do
    pen = pen_fixture()
    {:ok, view, _html} = live(conn, ~p"/pens/#{pen}")

    html =
      view
      |> form("#feeding-form", feeding: %{feed_type: "", amount_lb: "-5"})
      |> render_submit()

    assert html =~ "must be greater than 0"
  end
end
