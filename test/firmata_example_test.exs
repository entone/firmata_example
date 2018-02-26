defmodule FirmataExampleTest do
  use ExUnit.Case
  doctest FirmataExample

  test "greets the world" do
    assert FirmataExample.hello() == :world
  end
end
