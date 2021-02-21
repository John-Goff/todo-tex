defmodule TodoTex.Todo do
  @moduledoc """
  Work with individual todo line items.

  Provides a struct for representing a line item as well as functions to parse
  a `todo.txt` formatted line into a struct.
  """

  alias TodoTex.TodoParser

  defstruct priority: nil,
            start_date: nil,
            end_date: nil,
            done: false,
            projects: [],
            contexts: [],
            task: "",
            original: ""

  def parse(string) when is_binary(string) do
    case TodoParser.todo(string) do
      {:ok, [], "", _context, _line, _offset} ->
        {:error, :no_data}

      {:ok, metadata, task, _context, _line, _offset} ->
        todo =
          %__MODULE__{task: task, original: string}
          |> _add_metadata(metadata)
          |> _add_projects(task)
          |> _add_contexts(task)

        {:ok, todo}
    end
  end

  defp _add_metadata(todo, [{:done, done} | rest]),
    do: _add_metadata(%__MODULE__{todo | done: done}, rest)

  defp _add_metadata(todo, [{:priority, pri} | rest]),
    do: _add_metadata(%__MODULE__{todo | priority: pri}, rest)

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
end
