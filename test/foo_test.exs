defmodule FooTest do
  use ExUnit.Case
  import ExPact.ProviderCase

  honours_pact_with(:foo, :bar, "./example.json")
end
