defmodule TodoTexTest do
  use ExUnit.Case
  doctest TodoTex

  test "greets the world" do
    assert TodoTex.hello() == :world
  end
end
