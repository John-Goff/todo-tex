defmodule TodoTex do
  @moduledoc """
  Elixir library for reading and writing todo files in `todo.txt` format.

  The most basic operation is `TodoTex.read!/1`, which takes a path to a `txt`
  file in the `todo.txt` format. See [the todo.txt github](https://github.com/todotxt/todo.txt) for a description
  of the format.
  """

  @type t() :: %__MODULE__{
          path: String.t() | nil,
          items: [TodoTex.Todo.t()]
        }

  defstruct path: nil, items: []

  @doc """
  Reads a `todo.txt` file and returns a `TodoTex` struct with a list of todo items.

  ## Examples

      TodoTex.read!("/path/to/todo.txt")
      %TodoTex{path: "/path/to/todo.txt", list: [%TodoTex.Item{}, ...]}

  """
  @spec read!(path :: String.t()) :: t()
  def read!(path) when is_binary(path) do
    path = Path.absname(path)
    file = File.open!(path, [:read, :utf8])
    list = _parse_lines(file, [])
    File.close(file)
    %TodoTex{path: path, items: list}
  end

  defp _parse_lines(file, items) do
    case IO.read(file, :line) do
      :eof ->
        items

      {:error, _reason} ->
        items

      line_data ->
        _parse_lines(file, [TodoTex.Todo.parse!(String.trim_trailing(line_data)) | items])
    end
  end

  @doc """
  Marks the task at `index` as complete.

  Index starts at zero for the first task in the list. This function will not
  update the underlying `todo.txt` file, it will only change the tasks in
  memory. To write the changed tasks back to disk see `write!/1`.

  ## Examples

      iex> TodoTex.complete(%TodoTex{items: [%TodoTex.Todo{completed: false}]}, 0)
      %TodoTex{items: [%TodoTex.Todo{completed: true}]}

      iex> TodoTex.complete(%TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{completed: false}]}, 1)
      %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{completed: true}]}

  """
  @spec complete(t(), non_neg_integer()) :: t()
  def complete(%TodoTex{items: items} = todolist, index) when is_integer(index) and index >= 0 do
    %__MODULE__{todolist | items: List.update_at(items, index, &TodoTex.Todo.complete/1)}
  end

  @doc """
  Turns a todolist into a string.

  ## Examples

      iex> TodoTex.to_string(%TodoTex{items: [%TodoTex.Todo{task: "Call Mom"}, %TodoTex.Todo{task: "Buy groceries"}]})
      "Call Mom
      Buy groceries"

  """
  @spec to_string(todolist :: t()) :: String.t()
  def to_string(%TodoTex{items: items}),
    do: items |> Enum.map(&TodoTex.Todo.to_string/1) |> Enum.join("\n")

  @doc """
  Writes the todolist to disk.

  The contents of the file specified in the `path` key will be overwritten.
  """
  @spec write!(todolist :: t()) :: :ok | {:error, File.posix()}
  def write!(%TodoTex{path: path} = todolist) do
    File.write!(path, TodoTex.to_string(todolist))
  end
end

defimpl String.Chars, for: TodoTex do
  def to_string(%TodoTex{} = todolist), do: TodoTex.to_string(todolist)
end
