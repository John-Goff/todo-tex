defmodule TodoTex do
  @moduledoc """
  Elixir library for reading and writing ToDo files in `todo.txt` format.

  The most basic operation is `TodoTex.read!/1`, which takes a path to a `txt`
  file in the `todo.txt` format. See [the todo.txt github](https://github.com/todotxt/todo.txt) for a description
  of the format.
  """

  defstruct [:path, :items]

  @doc """
  Reads a `todo.txt` file and returns a `TodoTex` struct with a list of todo items.

  ## Examples

      TodoTex.read!("/path/to/todo.txt")
      %TodoTex{path: "/path/to/todo.txt", list: [%TodoTex.Item{}, ...]}

  """
  def read!(path) when is_binary(path) do
    file = File.open!(path, [:read, :utf8])
    list = parse_lines(file)
    File.close(file)
    %TodoTex{path: path, items: list}
  end
end
