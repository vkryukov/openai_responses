defmodule OpenaiResponsesTest do
  use ExUnit.Case
  doctest OpenaiResponses

  test "greets the world" do
    assert OpenaiResponses.hello() == :world
  end
end
