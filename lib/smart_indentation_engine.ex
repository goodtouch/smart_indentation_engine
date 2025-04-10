defmodule SmartIndentationEngine do
  @moduledoc """
  A custom EEx engine that helps maintain proper indentation.

  This engine extends the EEx.SmartEngine functionality and adds support for the
  pipe marker (`<%|`) which can be used like this:

      <%| if cond do %>
        Some text
      <% end %>

  This marker will reindent the output of the block so that it's aligned with
  indentation of the `if` line.
  """

  @behaviour EEx.Engine

  # Delegate basic functionality to EEx.Engine

  @impl true
  defdelegate init(opts), to: EEx.Engine

  @impl true
  defdelegate handle_body(state), to: EEx.Engine

  @impl true
  defdelegate handle_begin(state), to: EEx.Engine

  @impl true
  defdelegate handle_end(state), to: EEx.Engine

  @impl true
  defdelegate handle_text(state, meta, text), to: EEx.Engine

  @impl true
  def handle_expr(%{vars_count: vars_count, binary: binary} = state, "|", expr) do
    [current_indentation, block_indentation] = indentation_state(state, expr)

    # Don't output empty newline for `<%| ... do %>` lines
    binary = trim_empty_block_line(binary, expr)

    # Create new variables (i.e. arg0, arg1, ...) (see default EEx.Engine impl)
    var = Macro.var(:"arg#{vars_count}", __MODULE__)

    ast =
      expr
      # Process assigns like @foo before handling the expression
      |> Macro.prewalk(&EEx.Engine.handle_assign/1)
      |> then(&quote(do: String.Chars.to_string(unquote(&1))))
      |> maybe_replace_block_indentation(current_indentation, block_indentation)
      |> maybe_trim_first_line(binary)
      |> trim_last_block_newline()
      |> then(&quote(do: unquote(var) = unquote(&1)))

    # Create an AST for a binary segment referencing arg0 that will be used to
    # form the template output (see default EEx.Engine impl)
    segment = quote(do: unquote(var) :: binary)

    %{
      state
      | dynamic: [ast | state.dynamic],
        binary: [segment | binary],
        vars_count: vars_count + 1
    }
  end

  def handle_expr(state, marker, expr) do
    [indentation, _] = indentation_state(state, expr)

    expr =
      expr
      # Process assigns like @foo before handling the expression
      |> Macro.prewalk(&EEx.Engine.handle_assign/1)
      # Reindent include calls
      |> Macro.postwalk(&handle_include(&1, indentation))

    EEx.Engine.handle_expr(state, marker, expr)
  end

  # Reindent include calls according to the indentation state
  defp handle_include({:include, _meta, _args} = include_call, indentation) do
    reindent_include_call(include_call, indentation)
  end

  defp handle_include(ast, _), do: ast

  # Extract current indentation and sub block indentation if any
  defp indentation_state(%{binary: binary}, expr) do
    # Extract indentation from the content before the `<%|` tag
    indentation =
      binary
      |> List.first("")
      |> trailing_whitespace()

    block_indentation =
      if has_do_block?(expr) do
        expr |> do_block |> block_indentation
      else
        indentation
      end

    [indentation, block_indentation]
  end

  defp trailing_whitespace(string) do
    case Regex.run(~r/([ \t]*)\Z/, string) do
      [_, whitespace] -> whitespace
      _ -> ""
    end
  end

  # Extracts the indentation from the binary concatenation part of the block
  # {:__block__, [],
  #  [
  #    {:=, [], [...]},
  #    ...
  #    {:<<>>, [],
  #     [
  #       "\n    ", # <-- this is the indentation we want to extract
  #       {:"::", [], ...},
  #       "\n  "
  #     ]}
  #  ]}
  defp block_indentation({:__block__, _meta, args}) when is_list(args) do
    last_arg = List.last(args)
    # extract first line indentation from binary concatenation
    case last_arg do
      {:<<>>, _meta, parts} ->
        case List.first(parts) do
          string when is_binary(string) ->
            # Extract the indentation from the string
            [_, indentation] = Regex.run(~r/^\n+([ \t]*)/, string)
            indentation

          _ ->
            ""
        end

      _ ->
        ""
    end
  end

  defp has_do_block?({_op, _meta, args}) when is_list(args) do
    last_arg = List.last(args)
    Keyword.keyword?(last_arg) && Keyword.has_key?(last_arg, :do)
  end

  defp has_do_block?(_), do: false

  defp do_block(ast) do
    ast
    |> Macro.path(fn
      {:__block__, _, _} -> true
      _ -> false
    end)
    |> List.first()
  end

  defp reindent_include_call({:include, meta, _args} = include_call, indentation) do
    quote(line: meta[:line] || 0) do
      unquote(include_call)
      |> String.split("\n")
      |> Enum.with_index()
      |> Enum.map(fn
        {"", _} -> ""
        # Skip the first line
        {line, 0} -> line
        {line, _} -> "#{unquote(indentation)}#{line}"
      end)
      |> Enum.join("\n")
    end
  end

  # Remove empty newline from binary if the expression is a block definition
  defp trim_empty_block_line([head | tail] = binary, expr) do
    if has_do_block?(expr) do
      [String.replace(head, ~r/\n[ \t]*\Z/, "") | tail]
    else
      binary
    end
  end

  defp trim_empty_block_line(binary, _), do: binary

  # Remove the last new line from the binary concatenation (the one before `<% end %>`)
  defp trim_last_block_newline(ast) do
    Macro.prewalk(ast, fn
      {:<<>>, meta, parts} ->
        new_parts =
          case List.last(parts) do
            last when is_binary(last) ->
              if Regex.match?(~r/\n[ \t]*$/, last) do
                # Remove the last new line
                clean_last = Regex.replace(~r/\n[ \t]*$/, last, "")
                List.replace_at(parts, length(parts) - 1, clean_last)
              else
                parts
              end

            _ ->
              parts
          end

        {:<<>>, meta, new_parts}

      other ->
        other
    end)
  end

  # Replace block indentation with current indentation if they differ
  defp maybe_replace_block_indentation(ast, current, current), do: ast
  defp maybe_replace_block_indentation(ast, current, block), do: replace_indentation(ast, block, current)

  defp replace_indentation(ast, indentation, new_indentation) do
    quote do
      String.replace(
        unquote(ast),
        ~r/\n#{unquote(indentation)}/,
        "\n#{unquote(new_indentation)}"
      )
    end
  end

  # Remove the first `\n` from the output if the binary is empty (i.e. the first
  # line of the template)
  defp maybe_trim_first_line(ast, []), do: trim_first_line(ast)
  defp maybe_trim_first_line(ast, _), do: ast

  defp trim_first_line(ast) do
    quote do
      String.replace(unquote(ast), ~r/^\n/, "")
    end
  end
end

defmodule SmartIndentationEngine.Template do
  @moduledoc """
  Provides the `~TT` sigil to compile templates with the
  `SmartIndentationEngine`, and the `include/2` macro for rendering partials.
  """

  @doc """
  Renders a partial defined by the given function name.

  ## Example

      <%= include :partial %>
      <%= include :partial, name: true %>

  This will call `partial/1` function with the current assigns.
  """
  # Note: only support keyword arguments for now, could be nice to add maps?
  defmacro include(partial_name, args \\ []) do
    quote do
      unquote(partial_name)(Keyword.merge(var!(assigns), unquote(args)))
    end
  end

  @doc ~S'''
  Compiles a template string using the `SmartIndentationEngine`.

  ## Example

      defmodule MyApp.Template do
        import SmartIndentationEngine.Template

        def render(assigns) do
          ~TT"""
          <%| case @lang do %>
            <% :fr -> %>
              <%= include :french %>
            <% _ -> %>
              <%= include :english %>
            <% end %>
          """
        end

        def french(assigns) do
          ~TT(Bonjour <%= @name %>)
        end

        def english(assigns) do
          ~TT(Hello <%= @name %>)
        end
      end

      MyApp.Template.render(lang: :fr, name: "John")
  '''
  defmacro sigil_TT({:<<>>, meta, [template_string]}, []) do
    template_string = String.replace(template_string, ~r/\n[ \t]*\z/, "")

    options = [
      engine: SmartIndentationEngine,
      file: __CALLER__.file,
      line: __CALLER__.line + 1,
      caller: __CALLER__,
      indentation: meta[:indentation] || 0
    ]

    EEx.compile_string(template_string, options)
  end
end
