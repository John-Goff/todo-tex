defmodule TodoTex do
  @moduledoc """
  Elixir library for reading and writing todo files in `todo.txt` format.

  The `todo.txt` format is a way of specifiying tasks in a plain `txt` file.
  See [the todo.txt github](https://github.com/todotxt/todo.txt) for a description of the format.
  This library intends to be a simple way to read, update, and write a
  `todo.txt` file.

  The most basic operation is `TodoTex.read!/1`, which takes a path to a `txt`
  file in the `todo.txt` format. This returns a `TodoTex` struct which holds
  all the todo items in the `items` key, as well as the `path` to later update
  the file. From here, you can use the functions in this module to update the
  todos inside the list, or you can manipulate the todos directly with the
  `TodoTex.Todo` module.

  `TodoTex` implements both the `Enumerable` and `Collectable` protocols.
  This means that you can use the functions in the `Enum` module to transform
  and work with todolists. Note however that an example such as this

      TodoTex.read!(path) |> Enum.map(&transform_todo/1) |> Enum.into(%TodoTex{})

  will work to transform each todo according to `transform_todo`, but it will
  discard the path information so the resulting todolist cannot be written
  unless it is updated with the correct path. For that reason, `TodoTex.map/2`
  is provided which will maintain path information.
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

      TodoTex.read!("rel/path/to/todo.txt")
      %TodoTex{path: "/abs/path/to/rel/path/to/todo.txt", list: [%TodoTex.Item{}, ...]}

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

      iex> TodoTex.complete(
      ...>   %TodoTex{items: [%TodoTex.Todo{completed: false}]},
      ...>   0
      ...> )
      %TodoTex{items: [%TodoTex.Todo{completed: true}]}

      iex> TodoTex.complete(
      ...>   %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{completed: false}]},
      ...>   1
      ...> )
      %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{completed: true}]}

  """
  @spec complete(t(), non_neg_integer()) :: t()
  def complete(%TodoTex{items: items} = todolist, index) when is_integer(index) and index >= 0 do
    %__MODULE__{todolist | items: List.update_at(items, index, &TodoTex.Todo.complete/1)}
  end

  @doc """
  Changes priority of task at `index`.

  Index starts at zero for the first task in the list. This function will not
  update the underlying `todo.txt` file, it will only change the tasks in
  memory. To write the changed tasks back to disk see `write!/1`.

  ## Examples

      iex> TodoTex.set_priority(
      ...>   %TodoTex{items: [%TodoTex.Todo{priority: "A"}]},
      ...>   0,
      ...>   "B"
      ...> )
      %TodoTex{items: [%TodoTex.Todo{priority: "B"}]}

      iex> TodoTex.set_priority(
      ...>   %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{priority: "B"}]},
      ...>   1,
      ...>   "A"
      ...> )
      %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{priority: "A"}]}

  """
  @spec set_priority(t(), non_neg_integer(), String.t()) :: t()
  def set_priority(%TodoTex{items: items} = todolist, index, priority)
      when is_integer(index) and index >= 0 do
    new_items =
      List.update_at(items, index, fn todo -> TodoTex.Todo.set_priority(todo, priority) end)

    %__MODULE__{todolist | items: new_items}
  end

  @doc """
  Changes start date of task at `index`.

  Index starts at zero for the first task in the list. This function will not
  update the underlying `todo.txt` file, it will only change the tasks in
  memory. To write the changed tasks back to disk see `write!/1`.

  ## Examples

      iex> TodoTex.set_start_date(
      ...>   %TodoTex{items: [%TodoTex.Todo{start_date: ~D[2021-01-01]}]},
      ...>   0,
      ...>   ~D[2021-01-02]
      ...> )
      %TodoTex{items: [%TodoTex.Todo{start_date: ~D[2021-01-02]}]}

      iex> TodoTex.set_start_date(
      ...>   %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{start_date: ~D[2021-01-01]}]},
      ...>   1,
      ...>   ~D[2021-01-02]
      ...> )
      %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{start_date: ~D[2021-01-02]}]}

  """
  @spec set_start_date(t(), non_neg_integer(), Date.t()) :: t()
  def set_start_date(%TodoTex{items: items} = todolist, index, date)
      when is_integer(index) and index >= 0 do
    new_items =
      List.update_at(items, index, fn todo -> TodoTex.Todo.set_start_date(todo, date) end)

    %__MODULE__{todolist | items: new_items}
  end

  @doc """
  Changes end date of task at `index`.

  Index starts at zero for the first task in the list. This function will not
  update the underlying `todo.txt` file, it will only change the tasks in
  memory. To write the changed tasks back to disk see `write!/1`.

  ## Examples

      iex> TodoTex.set_end_date(
      ...>   %TodoTex{items: [%TodoTex.Todo{end_date: ~D[2021-01-01]}]},
      ...>   0,
      ...>   ~D[2021-01-02]
      ...> )
      %TodoTex{items: [%TodoTex.Todo{end_date: ~D[2021-01-02]}]}

      iex> TodoTex.set_end_date(
      ...>   %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{end_date: ~D[2021-01-01]}]},
      ...>   1,
      ...>   ~D[2021-01-02]
      ...> )
      %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{end_date: ~D[2021-01-02]}]}

  """
  @spec set_end_date(t(), non_neg_integer(), Date.t()) :: t()
  def set_end_date(%TodoTex{items: items} = todolist, index, date)
      when is_integer(index) and index >= 0 do
    new_items = List.update_at(items, index, fn todo -> TodoTex.Todo.set_end_date(todo, date) end)

    %__MODULE__{todolist | items: new_items}
  end

  @doc """
  Prepends to task at `index`.

  Index starts at zero for the first task in the list. This function will not
  update the underlying `todo.txt` file, it will only change the tasks in
  memory. To write the changed tasks back to disk see `write!/1`.

  ## Examples

      iex> TodoTex.prepend_task(
      ...>   %TodoTex{items: [%TodoTex.Todo{task: " is incomplete"}]},
      ...>   0,
      ...>   "This task"
      ...> )
      %TodoTex{items: [%TodoTex.Todo{task: "This task is incomplete"}]}

      iex> TodoTex.prepend_task(
      ...>   %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{task: " is incomplete"}]},
      ...>   1,
      ...>   "This task"
      ...> )
      %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{task: "This task is incomplete"}]}

  """
  @spec prepend_task(t(), non_neg_integer(), String.t()) :: t()
  def prepend_task(%TodoTex{items: items} = todolist, index, task)
      when is_integer(index) and index >= 0 do
    new_items = List.update_at(items, index, fn todo -> TodoTex.Todo.prepend_task(todo, task) end)

    %__MODULE__{todolist | items: new_items}
  end

  @doc """
  Appends to task at `index`.

  Index starts at zero for the first task in the list. This function will not
  update the underlying `todo.txt` file, it will only change the tasks in
  memory. To write the changed tasks back to disk see `write!/1`.

  ## Examples

      iex> TodoTex.append_task(
      ...>   %TodoTex{items: [%TodoTex.Todo{task: "This task"}]},
      ...>   0,
      ...>   " is incomplete"
      ...> )
      %TodoTex{items: [%TodoTex.Todo{task: "This task is incomplete"}]}

      iex> TodoTex.append_task(
      ...>   %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{task: "This task"}]},
      ...>   1,
      ...>   " is incomplete"
      ...> )
      %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{task: "This task is incomplete"}]}

  """
  @spec append_task(t(), non_neg_integer(), String.t()) :: t()
  def append_task(%TodoTex{items: items} = todolist, index, task)
      when is_integer(index) and index >= 0 do
    new_items = List.update_at(items, index, fn todo -> TodoTex.Todo.append_task(todo, task) end)

    %__MODULE__{todolist | items: new_items}
  end

  @doc """
  Sets the task at `index`.

  Index starts at zero for the first task in the list. This function will not
  update the underlying `todo.txt` file, it will only change the tasks in
  memory. To write the changed tasks back to disk see `write!/1`.

  ## Examples

      iex> TodoTex.set_task(
      ...>   %TodoTex{items: [%TodoTex.Todo{task: "This task is replaced"}]},
      ...>   0,
      ...>   "This task is set"
      ...> )
      %TodoTex{items: [%TodoTex.Todo{task: "This task is set"}]}

      iex> TodoTex.set_task(
      ...>   %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{task: "This task is replaced"}]},
      ...>   1,
      ...>   "This task is set"
      ...> )
      %TodoTex{items: [%TodoTex.Todo{}, %TodoTex.Todo{task: "This task is set"}]}

  """
  @spec set_task(t(), non_neg_integer(), String.t()) :: t()
  def set_task(%TodoTex{items: items} = todolist, index, task)
      when is_integer(index) and index >= 0 do
    new_items = List.update_at(items, index, fn todo -> TodoTex.Todo.set_task(todo, task) end)

    %__MODULE__{todolist | items: new_items}
  end

  @doc """
  Turns a todolist into a string.

  ## Examples

      iex> TodoTex.to_string(
      ...>   %TodoTex{items: [
      ...>     %TodoTex.Todo{task: "Call Mom"},
      ...>     %TodoTex.Todo{task: "Buy groceries"}
      ...>   ]}
      ...> )
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

  @doc """
  Transforms each todo in the todolist according to `fun`.

  Note that the functions in the `Enum` module are also supported, as well as
  `for` comprehensions. However these will not maintain `path` so the
  `todolist` cannot be written back to disk. This function does maintain
  the `path` field.
  """
  def map(%TodoTex{items: items} = todolist, fun) when is_function(fun, 1) do
    %TodoTex{todolist | items: Enum.map(items, fun)}
  end
end

defimpl String.Chars, for: TodoTex do
  def to_string(%TodoTex{} = todolist), do: TodoTex.to_string(todolist)
end

defimpl Enumerable, for: TodoTex do
  def count(%TodoTex{}), do: {:error, __MODULE__}
  def member?(%TodoTex{}, _item), do: {:error, __MODULE__}
  def slice(%TodoTex{}), do: {:error, __MODULE__}

  def reduce(_todolist, {:halt, acc}, _fun), do: {:halted, acc}

  def reduce(%TodoTex{} = todolist, {:suspend, acc}, fun),
    do: {:suspended, acc, &reduce(todolist, &1, fun)}

  def reduce(%TodoTex{items: []}, {:cont, acc}, _fun), do: {:done, acc}

  def reduce(%TodoTex{items: [head | tail]} = todolist, {:cont, acc}, fun),
    do: reduce(%TodoTex{todolist | items: tail}, fun.(head, acc), fun)
end

defimpl Collectable, for: TodoTex do
  def into(list) do
    collector_fun = fn
      todolist, {:cont, %TodoTex.Todo{} = elem} ->
        %TodoTex{todolist | items: [elem | todolist.items]}

      todolist, :done ->
        todolist

      _todolist, :halt ->
        :ok
    end

    {list, collector_fun}
  end
end
