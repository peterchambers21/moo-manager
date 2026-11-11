defmodule CattleManagerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  setup do
    on_exit(&Cattle.TestHelpers.stop_all_cows/0)
  end

  describe "start_cow/4" do
    test "starts the cow under Cattle.CowSupervisor" do
      {:ok, pid} = CattleManager.start_cow("a", 2, :ok, :pen1)

      supervised =
        for {_, p, _, _} <- DynamicSupervisor.which_children(Cattle.CowSupervisor), do: p

      assert pid in supervised
    end

    test "the cow outlives the process that started it" do
      {:ok, pid} =
        Task.async(fn -> CattleManager.start_cow("a", 2, :ok, :pen1) end) |> Task.await()

      assert Process.alive?(pid)
      assert CattleManager.get_cow_info("a").location == :pen1
    end
  end

  test "list_cows/0 returns every registered cow" do
    for id <- ["a", "b", "c"], do: {:ok, _} = CattleManager.start_cow(id, 2, :ok, :pen1)
    assert Enum.sort(CattleManager.list_cows()) == ["a", "b", "c"]
  end

  test "get_cows_by_location/1 filters by current location" do
    {:ok, _} = CattleManager.start_cow("a", 2, :ok, :pen1)
    {:ok, _} = CattleManager.start_cow("b", 2, :ok, :pen2)
    {:ok, _} = CattleManager.start_cow("c", 2, :ok, :pen1)
    CattleManager.move_cow("c", :pen2)

    assert CattleManager.get_cows_by_location(:pen1) == ["a"]
    assert Enum.sort(CattleManager.get_cows_by_location(:pen2)) == ["b", "c"]
  end

  test "herd_average_weight/0 averages per-cow averages, skipping cows with no weights" do
    {:ok, _} = CattleManager.start_cow("a", 2, :ok, :pen1)
    {:ok, _} = CattleManager.start_cow("b", 2, :ok, :pen1)
    {:ok, _} = CattleManager.start_cow("unweighed", 2, :ok, :pen1)
    # a averages 300, b averages 400
    CattleManager.record_cow_weight("a", 300)
    Enum.each([380, 420], &CattleManager.record_cow_weight("b", &1))

    assert CattleManager.herd_average_weight() == 350.0
  end

  test "location_average_weight/1 only counts cows at that location" do
    {:ok, _} = CattleManager.start_cow("a", 2, :ok, :pen1)
    {:ok, _} = CattleManager.start_cow("b", 2, :ok, :pen2)
    CattleManager.record_cow_weight("a", 300)
    CattleManager.record_cow_weight("b", 500)

    assert CattleManager.location_average_weight(:pen1) == 300.0
  end

  test "average_growth_rate/0 averages growth across the herd" do
    {:ok, _} =
      Cattle.CowSupervisor.start_cow(%{
        id: "a",
        age: 2,
        health: :ok,
        location: :pen1,
        weights: [{~D[2025-01-11], 320}, {~D[2025-01-01], 300}]
      })

    {:ok, _} =
      Cattle.CowSupervisor.start_cow(%{
        id: "b",
        age: 2,
        health: :ok,
        location: :pen1,
        weights: [{~D[2025-01-11], 340}, {~D[2025-01-01], 300}]
      })

    assert CattleManager.average_growth_rate() == 3.0
  end

  test "herd queries skip a cow that crashes instead of crashing the caller" do
    {:ok, _} = CattleManager.start_cow("a", 2, :ok, :pen1)
    CattleManager.record_cow_weight("a", 300)

    # A registered process that dies as soon as it is called.
    parent = self()

    bad =
      spawn(fn ->
        Registry.register(Cattle.CattleRegistry, "bad", nil)
        send(parent, :registered)

        receive do
          _ -> exit(:boom)
        end
      end)

    assert_receive :registered

    capture_log(fn ->
      assert CattleManager.herd_average_weight() == 300.0
    end)

    refute Process.alive?(bad)
  end
end
