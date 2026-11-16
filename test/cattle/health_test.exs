defmodule Cattle.HealthTest do
  use Cattle.DataCase, async: true

  alias Cattle.{Health, Herd}

  defp treat(animal, occurred_on, withdrawal_until) do
    {:ok, event} =
      Health.record_event(animal, %{
        occurred_on: occurred_on,
        kind: :treatment,
        description: "Foot rot",
        product: "Penicillin",
        dose: "20 mL",
        withdrawal_until: withdrawal_until
      })

    event
  end

  describe "record_event/2" do
    test "records an event" do
      animal = animal_fixture()
      event = treat(animal, ~D[2025-02-01], ~D[2025-02-15])
      assert event.animal_id == animal.id
      assert event.kind == :treatment
      assert event.dose == "20 mL"
    end

    test "requires date, kind and description" do
      assert {:error, cs} = Health.record_event(animal_fixture(), %{})

      assert %{occurred_on: ["can't be blank"], kind: ["can't be blank"], description: _} =
               errors_on(cs)
    end

    test "rejects an unknown kind" do
      assert {:error, cs} =
               Health.record_event(animal_fixture(), %{
                 occurred_on: ~D[2025-02-01],
                 kind: :surgery,
                 description: "x"
               })

      assert errors_on(cs).kind == ["is invalid"]
    end

    test "rejects dates before arrival and withdrawal before the event" do
      animal = animal_fixture(%{arrival_date: ~D[2025-02-01]})

      assert {:error, cs} =
               Health.record_event(animal, %{
                 occurred_on: ~D[2025-01-31],
                 kind: :observation,
                 description: "Limping",
                 withdrawal_until: ~D[2025-01-30]
               })

      assert errors_on(cs).occurred_on == ["can't be before arrival date"]
      assert errors_on(cs).withdrawal_until == ["can't be before the event date"]
    end
  end

  test "list_events/1 is newest first" do
    animal = animal_fixture()
    older = treat(animal, ~D[2025-02-01], nil)
    newer = treat(animal, ~D[2025-03-01], nil)
    assert Enum.map(Health.list_events(animal), & &1.id) == [newer.id, older.id]
  end

  describe "withdrawal" do
    test "under_withdrawal?/2 includes the last withdrawal day" do
      animal = animal_fixture()
      treat(animal, ~D[2025-02-01], ~D[2025-02-15])

      assert Health.under_withdrawal?(animal, ~D[2025-02-01])
      assert Health.under_withdrawal?(animal, ~D[2025-02-15])
      refute Health.under_withdrawal?(animal, ~D[2025-02-16])
      refute Health.under_withdrawal?(animal_fixture(), ~D[2025-02-01])
    end

    test "animals_under_withdrawal/1 lists active animals by when they clear" do
      late = animal_fixture(%{tag: "late"})
      treat(late, ~D[2025-02-01], ~D[2025-02-10])
      treat(late, ~D[2025-02-05], ~D[2025-03-01])

      soon = animal_fixture(%{tag: "soon"})
      treat(soon, ~D[2025-02-01], ~D[2025-02-20])

      cleared = animal_fixture(%{tag: "cleared"})
      treat(cleared, ~D[2025-01-01], ~D[2025-01-10])

      dead = animal_fixture(%{tag: "dead"})
      treat(dead, ~D[2025-02-01], ~D[2025-03-01])
      {:ok, _} = Herd.record_death(dead, ~D[2025-02-02])

      result = Health.animals_under_withdrawal(~D[2025-02-15])

      assert Enum.map(result, fn {animal, until} -> {animal.tag, until} end) == [
               {"soon", ~D[2025-02-20]},
               {"late", ~D[2025-03-01]}
             ]
    end
  end
end
