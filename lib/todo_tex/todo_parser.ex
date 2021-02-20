defmodule TodoTex.ParserHelper do
  @moduledoc false

  import NimbleParsec

  def map_priority(pri), do: {:priority, <<pri>>}

  def map_date(_rest, results, context, _line, _offset, tag) do
    {[{:date, tag, apply(Date, :new!, Enum.reverse(results))}], context}
  end
end

defmodule TodoTex.TodoParser do
  import NimbleParsec

  done = ascii_char([?x]) |> replace({:done, true})

  priority =
    ignore(string("("))
    |> ascii_char([?A..?Z])
    |> ignore(string(")"))
    |> map({TodoTex.ParserHelper, :map_priority, []})

  date =
    integer(4)
    |> ignore(string("-"))
    |> integer(2)
    |> ignore(string("-"))
    |> integer(2)

  defparsec(
    :todo,
    optional(done)
    |> optional(ignore(string(" ")))
    |> optional(priority)
    |> optional(ignore(string(" ")))
    |> optional(post_traverse(date, {TodoTex.ParserHelper, :map_date, [:end]}))
    |> optional(ignore(string(" ")))
    |> optional(post_traverse(date, {TodoTex.ParserHelper, :map_date, [:start]}))
    |> optional(ignore(string(" ")))
  )
end
