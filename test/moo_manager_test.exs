defmodule MooManagerTest do
  use ExUnit.Case
  doctest MooManager

  test "greets the world" do
    assert MooManager.hello() == :world
  end
end
