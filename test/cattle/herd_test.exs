defmodule Cattle.HerdTest do
  use Cattle.DataCase, async: true

  alias Cattle.{Feed, Health, Herd}

  describe "pens" do
    test "create_pen/1 requires a unique name" do
      assert {:ok, pen} = Herd.create_pen(%{name: " North 1 ", capacity: 100})
      assert pen.name == "North 1"

      assert {:error, cs} = Herd.create_pen(%{name: "North 1"})
      assert "has already been taken" in errors_on(cs).name

      assert {:error, cs} = Herd.create_pen(%{name: ""})
      assert "can't be blank" in errors_on(cs).name
    end

    test "create_pen/1 rejects a non-positive capacity" do
      assert {:error, cs} = Herd.create_pen(%{name: "P", capacity: 0})
      assert errors_on(cs).capacity != []
    end

    test "list_pens/0 is ordered by name and get_pen_by_name/1 finds one" do
      b = pen_fixture(%{name: "B"})
      a = pen_fixture(%{name: "A"})
      assert Enum.map(Herd.list_pens(), & &1.id) == [a.id, b.id]
      assert Herd.get_pen_by_name("B").id == b.id
    end

    test "delete_pen/1 deletes an unused pen" do
      pen = pen_fixture()
      assert {:ok, _} = Herd.delete_pen(pen)
      assert Herd.list_pens() == []
    end

    test "delete_pen/1 refuses a pen that animals or feedings reference" do
      with_animal = pen_fixture()
      animal_fixture(%{pen_id: with_animal.id})
      assert {:error, cs} = Herd.delete_pen(with_animal)
      assert errors_on(cs).animals != []

      with_feeding = pen_fixture()

      {:ok, _} =
        Feed.record_feeding(with_feeding, %{
          fed_on: ~D[2025-01-02],
          feed_type: "hay",
          amount_lb: 10
        })

      assert {:error, cs} = Herd.delete_pen(with_feeding)
      assert errors_on(cs).feedings != []
    end
  end

  describe "register_animal/1" do
    test "registers an active animal" do
      pen = pen_fixture()

      assert {:ok, animal} =
               Herd.register_animal(%{
                 tag: " 1042 ",
                 arrival_date: ~D[2025-03-01],
                 sex: :steer,
                 breed: "Angus",
                 pen_id: pen.id
               })

      assert animal.tag == "1042"
      assert animal.status == :active
      assert animal.departure_date == nil
      assert Herd.get_animal_by_tag("1042").id == animal.id
    end

    test "requires tag and arrival date" do
      assert {:error, cs} = Herd.register_animal(%{})
      assert %{tag: ["can't be blank"], arrival_date: ["can't be blank"]} = errors_on(cs)
    end

    test "rejects a duplicate tag" do
      animal_fixture(%{tag: "1042"})
      assert {:error, cs} = Herd.register_animal(%{tag: "1042", arrival_date: ~D[2025-01-01]})
      assert "has already been taken" in errors_on(cs).tag
    end

    test "rejects an unknown sex and a birth date after arrival" do
      assert {:error, cs} =
               Herd.register_animal(%{
                 tag: "x",
                 arrival_date: ~D[2025-01-01],
                 birth_date: ~D[2025-02-01],
                 sex: :unicorn
               })

      assert errors_on(cs).sex == ["is invalid"]
      assert errors_on(cs).birth_date == ["can't be after arrival date"]
    end

    test "records the arrival weight as the first weigh-in" do
      animal = animal_fixture(%{arrival_date: ~D[2025-03-01], arrival_weight_lb: 650})
      assert [weigh_in] = Herd.list_weigh_ins(animal)
      assert weigh_in.weighed_on == ~D[2025-03-01]
      assert_decimal(weigh_in.weight_lb, 650)
    end

    test "an invalid arrival weight saves nothing" do
      assert {:error, cs} =
               Herd.register_animal(%{
                 tag: "x",
                 arrival_date: ~D[2025-01-01],
                 arrival_weight_lb: 0
               })

      assert errors_on(cs).arrival_weight_lb != []
      assert Herd.get_animal_by_tag("x") == nil
    end

    test "won't put an animal in a full pen" do
      pen = pen_fixture(%{capacity: 1})
      animal_fixture(%{pen_id: pen.id})

      assert {:error, cs} =
               Herd.register_animal(%{tag: "x", arrival_date: ~D[2025-01-01], pen_id: pen.id})

      assert errors_on(cs).pen_id == ["pen is full"]
    end

    test "rejects a pen that doesn't exist" do
      assert {:error, cs} =
               Herd.register_animal(%{tag: "x", arrival_date: ~D[2025-01-01], pen_id: -1})

      assert errors_on(cs).pen_id == ["does not exist"]
    end
  end

  describe "list_animals/1" do
    test "defaults to active animals, filters by pen and status" do
      pen = pen_fixture()
      a = animal_fixture(%{tag: "A", pen_id: pen.id})
      b = animal_fixture(%{tag: "B"})
      c = animal_fixture(%{tag: "C", pen_id: pen.id})
      {:ok, _} = Herd.record_death(c, ~D[2025-02-01])

      assert Enum.map(Herd.list_animals(), & &1.id) == [a.id, b.id]
      assert Enum.map(Herd.list_animals(pen: pen), & &1.id) == [a.id]
      assert Enum.map(Herd.list_animals(status: :dead), & &1.id) == [c.id]
      assert length(Herd.list_animals(status: :all)) == 3
    end
  end

  describe "move_animal/2" do
    test "moves into another pen and out of any pen" do
      pen1 = pen_fixture()
      pen2 = pen_fixture()
      animal = animal_fixture(%{pen_id: pen1.id})

      assert {:ok, animal} = Herd.move_animal(animal, pen2)
      assert animal.pen_id == pen2.id
      assert Herd.head_count(pen1) == 0
      assert Herd.head_count(pen2) == 1

      assert {:ok, animal} = Herd.move_animal(animal, nil)
      assert animal.pen_id == nil
    end

    test "respects pen capacity" do
      full = pen_fixture(%{capacity: 1})
      animal_fixture(%{pen_id: full.id})
      animal = animal_fixture()

      assert {:error, cs} = Herd.move_animal(animal, full)
      assert errors_on(cs).pen_id == ["pen is full"]
    end

    test "refuses animals that have left" do
      animal = animal_fixture()
      {:ok, shipped} = Herd.ship_animal(animal, ~D[2025-02-01])
      assert Herd.move_animal(shipped, pen_fixture()) == {:error, :not_active}
    end
  end

  describe "weigh-ins" do
    test "record_weight/3 accepts a past date; list is newest first" do
      animal = animal_fixture(%{arrival_date: ~D[2025-01-01]})
      {:ok, _} = Herd.record_weight(animal, 600, ~D[2025-01-01])
      {:ok, _} = Herd.record_weight(animal, "640.25", ~D[2025-02-01])

      assert [latest, first] = Herd.list_weigh_ins(animal)
      assert latest.weighed_on == ~D[2025-02-01]
      assert_decimal(latest.weight_lb, "640.3")
      assert first.weighed_on == ~D[2025-01-01]
      assert_decimal(Herd.latest_weight(animal), "640.3")
    end

    test "record_weight/3 defaults to today" do
      animal = animal_fixture()
      {:ok, weigh_in} = Herd.record_weight(animal, 600)
      assert weigh_in.weighed_on == Date.utc_today()
    end

    test "record_weight/3 rejects bad weights and dates before arrival" do
      animal = animal_fixture(%{arrival_date: ~D[2025-01-10]})

      assert {:error, cs} = Herd.record_weight(animal, 0, ~D[2025-01-10])
      assert errors_on(cs).weight_lb != []

      assert {:error, cs} = Herd.record_weight(animal, 600, ~D[2025-01-09])
      assert errors_on(cs).weighed_on == ["can't be before arrival date"]
    end

    test "latest_weight/1 is nil for an animal never weighed" do
      assert Herd.latest_weight(animal_fixture()) == nil
    end
  end

  describe "average_daily_gain/1" do
    test "uses the first and latest weigh-ins" do
      animal = animal_fixture()
      {:ok, _} = Herd.record_weight(animal, 600, ~D[2025-01-01])
      {:ok, _} = Herd.record_weight(animal, 610, ~D[2025-01-11])
      {:ok, _} = Herd.record_weight(animal, 700, ~D[2025-01-21])

      # (700 - 600) / 20 days
      assert_decimal(Herd.average_daily_gain(animal), "5.00")
    end

    test "reports a loss as negative gain" do
      animal = animal_fixture()
      {:ok, _} = Herd.record_weight(animal, 600, ~D[2025-01-01])
      {:ok, _} = Herd.record_weight(animal, 590, ~D[2025-01-05])
      assert_decimal(Herd.average_daily_gain(animal), "-2.50")
    end

    test "is nil with one weigh-in or all on the same day" do
      animal = animal_fixture()
      assert Herd.average_daily_gain(animal) == nil
      {:ok, _} = Herd.record_weight(animal, 600, ~D[2025-01-01])
      assert Herd.average_daily_gain(animal) == nil
      {:ok, _} = Herd.record_weight(animal, 610, ~D[2025-01-01])
      assert Herd.average_daily_gain(animal) == nil
    end
  end

  describe "pen and herd metrics" do
    setup do
      pen = pen_fixture()
      other_pen = pen_fixture()

      # a: 600 -> 700 over 10 days (10 lb/day), latest 700
      a = animal_fixture(%{pen_id: pen.id})
      {:ok, _} = Herd.record_weight(a, 600, ~D[2025-01-01])
      {:ok, _} = Herd.record_weight(a, 700, ~D[2025-01-11])

      # b: 800 -> 800 (0 lb/day), latest 800
      b = animal_fixture(%{pen_id: pen.id})
      {:ok, _} = Herd.record_weight(b, 800, ~D[2025-01-01])
      {:ok, _} = Herd.record_weight(b, 800, ~D[2025-01-11])

      # c: only weighed once, in another pen
      c = animal_fixture(%{pen_id: other_pen.id})
      {:ok, _} = Herd.record_weight(c, 1000, ~D[2025-01-01])

      # d: died, so excluded everywhere
      d = animal_fixture(%{pen_id: pen.id})
      {:ok, _} = Herd.record_weight(d, 100, ~D[2025-01-01])
      {:ok, _} = Herd.record_weight(d, 200, ~D[2025-01-02])
      {:ok, _} = Herd.record_death(d, ~D[2025-01-03])

      # never weighed: excluded from weight averages
      animal_fixture(%{pen_id: pen.id})

      %{pen: pen, other_pen: other_pen}
    end

    test "head_count/1 counts active animals only", %{pen: pen, other_pen: other_pen} do
      assert Herd.head_count(pen) == 3
      assert Herd.head_count(other_pen) == 1
    end

    test "average weights use each active animal's latest weigh-in", %{pen: pen} do
      assert_decimal(Herd.pen_average_weight(pen), 750)
      assert_decimal(Herd.herd_average_weight(), "833.3")
    end

    test "average daily gain includes zero gain", %{pen: pen, other_pen: other_pen} do
      assert_decimal(Herd.pen_average_daily_gain(pen), "5.00")
      assert_decimal(Herd.herd_average_daily_gain(), "5.00")
      assert Herd.pen_average_daily_gain(other_pen) == nil
    end

    test "metrics are nil for an empty pen" do
      empty = pen_fixture()
      assert Herd.pen_average_weight(empty) == nil
      assert Herd.pen_average_daily_gain(empty) == nil
    end
  end

  describe "departures" do
    test "ship_animal/2 marks the animal shipped" do
      animal = animal_fixture()
      assert {:ok, shipped} = Herd.ship_animal(animal, ~D[2025-06-01])
      assert shipped.status == :shipped
      assert shipped.departure_date == ~D[2025-06-01]
    end

    test "ship_animal/2 is blocked during a withdrawal period" do
      animal = animal_fixture()

      {:ok, _} =
        Health.record_event(animal, %{
          occurred_on: ~D[2025-05-20],
          kind: :treatment,
          description: "BRD",
          product: "Oxytetracycline",
          withdrawal_until: ~D[2025-06-01]
        })

      assert Herd.ship_animal(animal, ~D[2025-06-01]) == {:error, :under_withdrawal}
      assert {:ok, _} = Herd.ship_animal(animal, ~D[2025-06-02])
    end

    test "record_death/2 marks the animal dead" do
      assert {:ok, dead} = Herd.record_death(animal_fixture(), ~D[2025-02-01])
      assert dead.status == :dead
    end

    test "departure can't be before arrival" do
      animal = animal_fixture(%{arrival_date: ~D[2025-01-10]})
      assert {:error, cs} = Herd.ship_animal(animal, ~D[2025-01-09])
      assert errors_on(cs).departure_date == ["can't be before arrival date"]
    end

    test "an animal can only leave once" do
      {:ok, dead} = Herd.record_death(animal_fixture(), ~D[2025-02-01])
      assert Herd.ship_animal(dead, ~D[2025-02-02]) == {:error, :not_active}
      assert Herd.record_death(dead, ~D[2025-02-02]) == {:error, :not_active}
    end
  end
end
