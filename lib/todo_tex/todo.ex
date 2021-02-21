defmodule TodoTex.Todo do
  @moduledoc """
  Work with individual todo line items.

  Provides a struct for representing a line item as well as functions to parse
  a `todo.txt` formatted line into a struct.
  """

  alias TodoTex.TodoParser

  @type t() :: %__MODULE__{
          priority: String.t() | nil,
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          done: boolean(),
          projects: [String.t()],
          contexts: [String.t()],
          task: String.t()
        }

  defstruct priority: nil,
            start_date: nil,
            end_date: nil,
            done: false,
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
      {:ok, %Todo{done: true, task: "Call Mom"}}

      iex> Todo.parse("x (A) 2021-01-02 2021-01-01 Make a New Years Resolution")
      {:ok,
        %Todo{
          done: true,
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
          |> _add_projects(task)
          |> _add_contexts(task)

        {:ok, todo}
    end
  end

  @doc """
  Same as `parse/1` but raises if the string could not be parsed.
  """
  @spec parse!(String.t()) :: t()
  def parse!(string) do
    case parse(string) do
      {:ok, todo} -> todo
      _error -> raise "could not parse todo"
    end
  end

  defp _add_metadata(todo, [{:done, done} | rest]),
    do: _add_metadata(%__MODULE__{todo | done: done}, rest)

  defp _add_metadata(todo, [{:priority, pri} | rest]),
    do: todo |> set_priority(pri) |> _add_metadata(rest)

  defp _add_metadata(todo, [{:date, :start, date} | rest]),
    do: _add_metadata(%__MODULE__{todo | start_date: date}, rest)

  defp _add_metadata(todo, [{:date, :end, date} | rest]),
    do: _add_metadata(%__MODULE__{todo | end_date: date}, rest)

  defp _add_metadata(todo, []), do: todo

  defp _add_projects(todo, task) do
    %__MODULE__{todo | projects: _substrings_starting_with(task, "+")}
  end

  defp _add_contexts(todo, task) do
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
      ...>   done: true,
      ...>   priority: "A",
      ...>   start_date: ~D[2021-01-01],
      ...>   end_date: ~D[2021-01-01]
      ...> })
      "x (A) 2021-01-01 2021-01-01 Call Mom"

  """
  def to_string(%__MODULE__{} = todo), do: _to_string(todo, "")

  defp _to_string(%__MODULE__{done: true} = todo, string) do
    _to_string(%__MODULE__{todo | done: false}, "x " <> string)
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

      iex> Todo.complete(%Todo{done: false})
      %Todo{done: true}

  """
  @spec complete(todo :: t()) :: t()
  def complete(%__MODULE__{} = todo), do: %__MODULE__{todo | done: true}

  @doc """
  Sets the priority to the specified value.

  Priority must be an uppercase ASCII letter (A-Z).
  """
  def set_priority(%__MODULE__{} = todo, <<priority::utf8>>) when priority in ?A..?Z,
    do: %__MODULE__{todo | priority: <<priority>>}
end
