defmodule TodoTex.ParserHelper do
  @moduledoc false

  import NimbleParsec

  def map_priority(pri), do: {:priority, <<pri>>}

  def map_date(_rest, results, context, _line, _offset, tag) do
    {[{:date, tag, apply(Date, :new!, Enum.reverse(results))}], context}
  end

  def map_end_and_start_date(_rest, results, context, _line, _offset) do
    [start_day, start_month, start_year, end_day, end_month, end_year] = results

    {[
       {:date, :start, Date.new!(start_year, start_month, start_day)},
       {:date, :end, Date.new!(end_year, end_month, end_day)}
     ], context}
  end

  def ignore_whitespace(combinator \\ empty()) do
    combinator
    |> ignore(repeat(ascii_char([?\s, ?\t])))
  end

  def done(combinator \\ empty()), do: combinator |> ascii_char([?x]) |> replace({:done, true})

  def priority(combinator \\ empty()) do
    combinator
    |> ignore(string("("))
    |> ascii_char([?A..?Z])
    |> ignore(string(")"))
    |> map({:map_priority, []})
  end

  def date(combinator \\ empty()) do
    combinator
    |> integer(4)
    |> ignore(string("-"))
    |> integer(2)
    |> ignore(string("-"))
    |> integer(2)
  end

  def start_date(combinator \\ empty()),
    do: combinator |> date() |> post_traverse({:map_date, [:start]})

  def end_and_start_date(combinator \\ empty()) do
    combinator
    |> date()
    |> ignore_whitespace()
    |> date()
    |> post_traverse({:map_end_and_start_date, []})
  end
end

defmodule TodoTex.TodoParser do
  import NimbleParsec
  import TodoTex.ParserHelper

  defparsec(
    :todo,
    optional(done())
    |> ignore_whitespace()
    |> optional(priority())
    |> ignore_whitespace()
    |> optional(choice([end_and_start_date(), start_date()]))
    |> ignore_whitespace()
  )
end
