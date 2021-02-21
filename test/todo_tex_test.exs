defmodule TodoTexTest do
  use ExUnit.Case
  doctest TodoTex

  describe "read!/1" do
    test "should read the example file correctly" do
      assert %TodoTex{items: items} = TodoTex.read!("test/todo.txt")
      assert length(items) == 4
    end
  end
end
