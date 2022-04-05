defmodule IoEffectsTest do
  use ExUnit.Case
  doctest IoEffects

  test "greets the world" do
    assert IoEffects.hello() == :world
  end
end
