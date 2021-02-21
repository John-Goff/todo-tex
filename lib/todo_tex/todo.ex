defmodule TodoTex.Todo do
  @moduledoc """
  Work with individual todo line items.

  Provides a struct for representing a line item as well as functions to parse
  a `todo.txt` formatted line into a struct. Setters are also provided for
  every field except `projects` and `contexts`. The correct way to update
  projects and contexts is to use one of `prepend_task/2`, `append_task/2` or
  `set_task/2` to add the project or context to the task text, which will also
  populate the `projects` and `contexts` fields of the struct. The reason for
  this is so users can decide whether they prefer appending or prepending new
  contexts/projects when they are added. Since the `todo.txt` format is meant
  to be human readable, providing as many options for formatting as possible
  while still adhering to the spec is a goal. Suggestions on how you are using
  `todo.txt` and how this library can better fit with your workflow are welcome.
  """

  alias TodoTex.TodoParser

  @type t() :: %__MODULE__{
          priority: String.t() | nil,
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          completed: boolean(),
          projects: [String.t()],
          contexts: [String.t()],
          task: String.t()
        }

  defstruct priority: nil,
            start_date: nil,
            end_date: nil,
            completed: false,
            projects: [],
            contexts: [],
            task: ""

  @doc """
  Turns a string into a properly formatted `%TodoTex.Todo{}` struct.

  The only string which will return an error is the empty string, `""`. All
  other strings can be considered to have at least a task, which is just plain
  text. If the string has other metadata, such as completion, date, or contexts,
  that will be filled into the returned struct correctly.

  ## Examples

      iex> Todo.parse("x Call Mom")
      {:ok, %Todo{completed: true, task: "Call Mom"}}

      iex> Todo.parse("x (A) 2021-01-02 2021-01-01 Make a New Years Resolution")
      {:ok,
        %Todo{
          completed: true,
          task: "Make a New Years Resolution",
          start_date: ~D[2021-01-01],
          end_date: ~D[2021-01-02],
          priority: "A"
        }}

      iex> Todo.parse("+projects and @contexts can be +anywhere in the @task")
      {:ok,
        %Todo{
          projects: ["projects", "anywhere"],
          contexts: ["contexts", "task"],
          task: "+projects and @contexts can be +anywhere in the @task",
        }}

      iex> Todo.parse("")
      {:error, :no_data}

      iex> Todo.parse(:badarg)
      ** (FunctionClauseError) no function clause matching in TodoTex.Todo.parse/1

  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, :no_data}
  def parse(string) when is_binary(string) do
    case TodoParser.todo(string) do
      {:ok, [], "", _context, _line, _offset} ->
        {:error, :no_data}

      {:ok, metadata, task, _context, _line, _offset} ->
        todo =
          %__MODULE__{task: task}
          |> _add_metadata(metadata)
          |> _add_projects()
          |> _add_contexts()

        {:ok, todo}
    end
  end

  @doc """
  Same as `parse/1` but raises if the string could not be parsed.

  ## Examples

      iex> Todo.parse!("x Call Mom")
      %Todo{completed: true, task: "Call Mom"}

      iex> Todo.parse!("")
      ** (ArgumentError) could not parse todo

  """
  @spec parse!(String.t()) :: t()
  def parse!(string) do
    case parse(string) do
      {:ok, todo} -> todo
      _error -> raise ArgumentError, "could not parse todo"
    end
  end

  defp _add_metadata(todo, [{:done, completed} | rest]),
    do: todo |> set_completed(completed) |> _add_metadata(rest)

  defp _add_metadata(todo, [{:priority, pri} | rest]),
    do: todo |> set_priority(pri) |> _add_metadata(rest)

  defp _add_metadata(todo, [{:date, :start, date} | rest]),
    do: todo |> set_start_date(date) |> _add_metadata(rest)

  defp _add_metadata(todo, [{:date, :end, date} | rest]),
    do: todo |> set_end_date(date) |> _add_metadata(rest)

  defp _add_metadata(todo, []), do: todo

  defp _add_projects(%__MODULE__{task: task} = todo) do
    %__MODULE__{todo | projects: _substrings_starting_with(task, "+")}
  end

  defp _add_contexts(%__MODULE__{task: task} = todo) do
    %__MODULE__{todo | contexts: _substrings_starting_with(task, "@")}
  end

  defp _substrings_starting_with(task, prefix) do
    task
    |> String.split()
    |> Enum.filter(fn str -> String.starts_with?(str, prefix) end)
    |> Enum.map(fn str -> str |> String.graphemes() |> tl() |> Enum.join() end)
  end

  @doc """
  Turns a `%TodoTex.Todo{}` struct into a string for display or writing to a file.

  The opposite of `parse/1`.

  ## Examples

      iex> Todo.to_string(%Todo{task: "Simple Task"})
      "Simple Task"

      iex> Todo.to_string(%Todo{
      ...>   task: "Learn to +drive @goals",
      ...>   priority: "C",
      ...>   start_date: ~D[2014-01-01],
      ...> })
      "(C) 2014-01-01 Learn to +drive @goals"

      iex> Todo.to_string(%Todo{
      ...>   task: "Call Mom",
      ...>   completed: true,
      ...>   priority: "A",
      ...>   start_date: ~D[2021-01-01],
      ...>   end_date: ~D[2021-01-01]
      ...> })
      "x (A) 2021-01-01 2021-01-01 Call Mom"

  """
  @spec to_string(todo :: t()) :: String.t()
  def to_string(%__MODULE__{} = todo), do: _to_string(todo, "")

  defp _to_string(%__MODULE__{completed: true} = todo, string) do
    _to_string(%__MODULE__{todo | completed: false}, "x " <> string)
  end

  defp _to_string(%__MODULE__{priority: pri} = todo, string) when not is_nil(pri) do
    _to_string(%__MODULE__{todo | priority: nil}, "#{string}(#{pri}) ")
  end

  defp _to_string(%__MODULE__{end_date: date} = todo, string) when not is_nil(date) do
    _to_string(%__MODULE__{todo | end_date: nil}, string <> Kernel.to_string(date) <> " ")
  end

  defp _to_string(%__MODULE__{start_date: date} = todo, string) when not is_nil(date) do
    _to_string(%__MODULE__{todo | start_date: nil}, string <> Kernel.to_string(date) <> " ")
  end

  defp _to_string(%__MODULE__{task: task}, string), do: string <> task

  @doc """
  Marks a single task as complete.

  Does not change the task on disk, only updates the returned task in memory.

  ## Examples

      iex> Todo.complete(%Todo{completed: false})
      %Todo{completed: true}

  """
  @spec complete(todo :: t()) :: t()
  def complete(%__MODULE__{} = todo), do: set_completed(todo, true)

  @doc """
  Sets completed to provided boolean value.

  Does not change the task on disk, only updates the returned task in memory.

  ## Examples

      iex> Todo.set_completed(%Todo{}, true)
      %Todo{completed: true}

      iex> Todo.set_completed(%Todo{}, false)
      %Todo{completed: false}

  """
  @spec set_completed(todo :: t(), complete :: boolean()) :: t()
  def set_completed(%__MODULE__{} = todo, complete) when is_boolean(complete),
    do: %__MODULE__{todo | completed: complete}

  @doc """
  Sets the priority to the specified value.

  Priority must be an uppercase ASCII letter (A-Z). Does not update the task on
  disk, only the returned task in memory.

  ## Examples

      iex> Todo.set_priority(%Todo{}, "A")
      %Todo{priority: "A"}

      iex> Todo.set_priority(%Todo{}, "Z")
      %Todo{priority: "Z"}

      iex> Todo.set_priority(%Todo{}, "AA")
      ** (FunctionClauseError) no function clause matching in TodoTex.Todo.set_priority/2

      iex> Todo.set_priority(%Todo{}, :badarg)
      ** (FunctionClauseError) no function clause matching in TodoTex.Todo.set_priority/2

  """
  @spec set_priority(todo :: t(), priority :: String.t()) :: t()
  def set_priority(%__MODULE__{} = todo, <<priority::utf8>>) when priority in ?A..?Z,
    do: %__MODULE__{todo | priority: <<priority>>}

  @doc """
  Sets the start date of a task.

  Does not update the task on disk, only the returned task in memory.

  ## Examples

      iex> Todo.set_start_date(%Todo{}, ~D[2021-01-01])
      %Todo{start_date: ~D[2021-01-01]}

      iex> Todo.set_start_date(%Todo{}, :badarg)
      ** (FunctionClauseError) no function clause matching in TodoTex.Todo.set_start_date/2

  """
  @spec set_start_date(todo :: t(), start_date :: Date.t()) :: t()
  def set_start_date(%__MODULE__{} = todo, %Date{} = date),
    do: %__MODULE__{todo | start_date: date}

  @doc """
  Sets the end date of a task.

  Does not update the task on disk, only the returned task in memory.

  ## Examples

      iex> Todo.set_end_date(%Todo{}, ~D[2021-01-01])
      %Todo{end_date: ~D[2021-01-01]}

      iex> Todo.set_end_date(%Todo{}, :badarg)
      ** (FunctionClauseError) no function clause matching in TodoTex.Todo.set_end_date/2

  """
  @spec set_end_date(todo :: t(), end_date :: Date.t()) :: t()
  def set_end_date(%__MODULE__{} = todo, %Date{} = date), do: %__MODULE__{todo | end_date: date}

  @doc """
  Prepends given string to the task.

  Will update the `projects` and `contexts` fields as well.

  ## Examples

      iex> Todo.prepend_task(%Todo{task: " is incomplete"}, "This task")
      %Todo{task: "This task is incomplete"}

  """
  @spec prepend_task(todo :: t(), String.t()) :: t()
  def prepend_task(%__MODULE__{task: task} = todo, text), do: set_task(todo, text <> task)

  @doc """
  Appends given string to the task.

  Will update the `projects` and `contexts` fields as well.

  ## Examples

      iex> Todo.append_task(%Todo{task: "This task"}, " is incomplete")
      %Todo{task: "This task is incomplete"}

  """
  @spec append_task(todo :: t(), String.t()) :: t()
  def append_task(%__MODULE__{task: task} = todo, text), do: set_task(todo, task <> text)

  @doc """
  Sets the task to the given string.

  Will update the `projects` and `contexts` fields as well.

  ## Examples

      iex> Todo.set_task(%Todo{task: "This task is replaced"}, "This task is set")
      %Todo{task: "This task is set"}

  """
  @spec set_task(todo :: t(), String.t()) :: t()
  def set_task(%__MODULE__{} = todo, text),
    do: %__MODULE__{todo | task: text} |> _add_projects() |> _add_contexts()
end
