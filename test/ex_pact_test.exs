defmodule ExPactTest do
  use ExUnit.Case
  doctest ExPact

  test "greets the world" do
    assert ExPact.hello() == :world
  end
end
