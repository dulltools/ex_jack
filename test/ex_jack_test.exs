defmodule ExJackTest do
  use ExUnit.Case
  doctest ExJack

  test "greets the world" do
    assert ExJack.hello() == :world
  end
end
