defmodule PipeTo do
  @doc """
  PipeTo operator.

  This operator will replace the placeholder argument `_` in the right-hand
  side function call with left-hand side expression.

  ### Examples

        iex> 1 ~> Enum.at(1..3, _)
        2

  It can mix with `|>` operation

  ### Examples

        iex> 1 ~> Enum.at(1..3, _) |> Kernel.*(5)
        10

  When using ~> withou placeholder `_`, it act just like `|>` pipe operator.

  ### Examples

        iex> [1, 2, 3] ~> Enum.take(2)
        [1, 2]

  You can also specify multiple target positions.

  ### Examples

        iex> 10 ~> Kernel.+(_, _)
        20
  """
  defmacro left ~> right do
    [{h, _} | t] = __MODULE__.unpipe({:~>, [], [left, right]})

    # Bascially follows `lib/elixir/lib/kernel` left |> right
    # https://github.com/elixir-lang/elixir/blob/master/lib/elixir/lib/kernel.ex#L3134
    fun = fn {x, positions}, acc ->
      case x do
        {op, _, [_]} when op == :+ or op == :- ->
          message =
            <<"piping into a unary operator is deprecated, please use the ",
              "qualified name. For example, Kernel.+(5), instead of +5">>

          :elixir_errors.warn(__CALLER__.line, __CALLER__.file, message)

        _ ->
          :ok
      end

      positions
      |> Enum.reverse()
      |> Enum.reduce(x, &Macro.pipe(acc, &2, &1))
    end

    :lists.foldl(fun, h, t)
  end

  @doc """
  Breaks a pipeline expression into a list. This is where the target position being calculated.

          PipeTo.unpipe(quote do: 5 ~> div(100, _) ~> div(2))
          # => [{5, 0},
          #     {{:div, [context: Elixir, import: Kernel], 'd'}, 1},
          #     {{:div, [], [2]}, 0}]
  """
  @spec unpipe(Macro.t) :: [Macro.t]
  def unpipe(expr) do
    :lists.reverse(unpipe(expr, []))
  end

  defp unpipe({:~>, _, [left, right]}, acc) do
    unpipe(right, unpipe(left, acc))
  end

  defp unpipe(ast = {_, _, args}, acc) when is_list(args) do
    positions =
      args
      |> Enum.with_index()
      |> Enum.reduce([], fn {arg, index}, positions ->
        cond do
          placeholder?(arg) -> [index | positions]
          true -> positions
        end
      end)
    fixed_ast = remove_placeholders(ast, positions)

    [{fixed_ast, pipe_positions(positions)} | acc]
  end

  defp unpipe(other, acc) do
    [{other, 0} | acc]
  end

  defp placeholder?({:_, _, _}),  do: true
  defp placeholder?(_), do: false

  defp remove_placeholders(ast, []), do: ast
  defp remove_placeholders({fun, meta, args}, [index | rest]) do
    {fun, meta, List.delete_at(args, index)}
    |> remove_placeholders(rest)
  end

  defp pipe_positions([]), do: [0]
  defp pipe_positions(positions), do: positions
end
