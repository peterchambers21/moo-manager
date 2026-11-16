defmodule Cattle.FeedTest do
  use Cattle.DataCase, async: true

  alias Cattle.Feed

  defp feed(pen, fed_on, amount) do
    {:ok, feeding} =
      Feed.record_feeding(pen, %{fed_on: fed_on, feed_type: "finishing ration", amount_lb: amount})

    feeding
  end

  describe "record_feeding/2" do
    test "records a delivery to a pen" do
      pen = pen_fixture()
      feeding = feed(pen, ~D[2025-01-01], "1250.55")
      assert feeding.pen_id == pen.id
      assert_decimal(feeding.amount_lb, "1250.6")
    end

    test "requires date, feed type and a positive amount" do
      assert {:error, cs} = Feed.record_feeding(pen_fixture(), %{amount_lb: 0})
      errors = errors_on(cs)
      assert errors.fed_on == ["can't be blank"]
      assert errors.feed_type == ["can't be blank"]
      assert errors.amount_lb != []
    end
  end

  describe "reporting" do
    setup do
      pen = pen_fixture()
      animal_fixture(%{pen_id: pen.id})
      animal_fixture(%{pen_id: pen.id})

      feed(pen, ~D[2025-01-01], 100)
      feed(pen, ~D[2025-01-02], 60)
      feed(pen, ~D[2025-01-05], 999)
      # another pen's feed never counts
      feed(pen_fixture(), ~D[2025-01-01], 5000)

      %{pen: pen}
    end

    test "list_feedings/3 is limited to the range, newest first", %{pen: pen} do
      assert pen
             |> Feed.list_feedings(~D[2025-01-01], ~D[2025-01-02])
             |> Enum.map(& &1.fed_on) == [~D[2025-01-02], ~D[2025-01-01]]
    end

    test "total_fed/3 sums the range, zero when nothing was fed", %{pen: pen} do
      assert_decimal(Feed.total_fed(pen, ~D[2025-01-01], ~D[2025-01-02]), 160)
      assert_decimal(Feed.total_fed(pen, ~D[2025-02-01], ~D[2025-02-28]), 0)
    end

    test "feed_per_head_per_day/3 divides by head count and days", %{pen: pen} do
      # 160 lb / (2 head * 2 days)
      assert_decimal(Feed.feed_per_head_per_day(pen, ~D[2025-01-01], ~D[2025-01-02]), "40.00")
    end

    test "feed_per_head_per_day/3 is nil for an empty pen" do
      empty = pen_fixture()
      feed(empty, ~D[2025-01-01], 100)
      assert Feed.feed_per_head_per_day(empty, ~D[2025-01-01], ~D[2025-01-01]) == nil
    end
  end
end
