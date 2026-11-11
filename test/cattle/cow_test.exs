defmodule Cattle.CowTest do
  use ExUnit.Case, async: false

  alias Cattle.Cow

  setup do
    on_exit(&Cattle.TestHelpers.stop_all_cows/0)
  end

  defp start_cow(attrs) do
    attrs = Map.merge(%{id: "bessie", age: 3, health: :ok, location: :pen1}, attrs)
    {:ok, pid} = Cattle.CowSupervisor.start_cow(attrs)
    {attrs.id, pid}
  end

  test "starts with empty logs and the given attributes" do
    {id, _pid} = start_cow(%{})

    assert %{id: "bessie", age: 3, health: :ok, location: :pen1} = info = Cow.get_info(id)
    assert info.weights == []
    assert info.feed_log == []
    assert info.health_log == []
  end

  test "keeps logs passed in at startup" do
    {id, _pid} = start_cow(%{weights: [{~D[2025-01-01], 300}]})
    assert Cow.get_weights(id) == [{~D[2025-01-01], 300}]
  end

  test "duplicate ids are rejected" do
    {_id, pid} = start_cow(%{})
    assert {:error, {:already_started, ^pid}} = Cattle.CowSupervisor.start_cow(%{id: "bessie"})
  end

  test "update_location changes the location" do
    {id, _pid} = start_cow(%{})
    :ok = Cow.update_location(id, :pen2)
    assert Cow.get_info(id).location == :pen2
  end

  test "update_health sets status and logs it for today, newest first" do
    {id, _pid} = start_cow(%{})
    Cow.update_health(id, :sick)
    Cow.update_health(id, :recovered)

    today = Date.utc_today()
    assert Cow.get_info(id).health == :recovered
    assert Cow.get_health_log(id) == [{today, :recovered}, {today, :sick}]
  end

  test "record_weight prepends today's weight" do
    {id, _pid} = start_cow(%{})
    Cow.record_weight(id, 300)
    Cow.record_weight(id, 310)

    today = Date.utc_today()
    assert Cow.get_weights(id) == [{today, 310}, {today, 300}]
  end

  test "feed_cow prepends a feed entry" do
    {id, _pid} = start_cow(%{})
    Cow.feed_cow(id, :hay, 12)
    Cow.feed_cow(id, :corn, 4)

    today = Date.utc_today()
    assert Cow.get_info(id).feed_log == [{today, :corn, 4}, {today, :hay, 12}]
  end

  describe "get_average_weight/1" do
    test "is 0.0 with no weights" do
      {id, _pid} = start_cow(%{})
      assert Cow.get_average_weight(id) == 0.0
    end

    test "is the mean of all weights" do
      {id, _pid} = start_cow(%{})
      Enum.each([300, 310, 320], &Cow.record_weight(id, &1))
      assert Cow.get_average_weight(id) == 310.0
    end
  end

  describe "get_growth_rate/1" do
    test "is 0.0 with fewer than two weights" do
      {id, _pid} = start_cow(%{weights: [{~D[2025-01-01], 300}]})
      assert Cow.get_growth_rate(id) == 0.0
    end

    test "is weight gained per day between two weigh-ins" do
      # newest-first, as stored
      weights = [{~D[2025-01-11], 330}, {~D[2025-01-01], 300}]
      {id, _pid} = start_cow(%{weights: weights})
      assert Cow.get_growth_rate(id) == 3.0
    end

    test "is 0.0 when both weigh-ins are on the same day" do
      {id, _pid} = start_cow(%{})
      Cow.record_weight(id, 300)
      Cow.record_weight(id, 320)
      assert Cow.get_growth_rate(id) == 0.0
    end
  end
end
