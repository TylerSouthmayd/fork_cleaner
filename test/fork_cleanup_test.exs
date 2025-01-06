defmodule ForkCleanerTest do
  use ExUnit.Case
  doctest ForkCleaner

  test "greets the world" do
    assert ForkCleaner.hello() == :world
  end
end
