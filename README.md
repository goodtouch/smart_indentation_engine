# Smart Indentation Engine

[![CI](https://github.com/goodtouch/smart_indentation_engine/actions/workflows/ci.yml/badge.svg)](https://github.com/goodtouch/smart_indentation_engine/actions/workflows/ci.yml)
[![License](https://img.shields.io/hexpm/l/smart_indentation_engine.svg)](https://github.com/goodtouch/smart_indentation_engine/blob/main/LICENSE.md)
[![Version](https://img.shields.io/hexpm/v/smart_indentation_engine.svg)](https://hex.pm/packages/smart_indentation_engine)
[![Hex Docs](https://img.shields.io/badge/documentation-gray.svg)](https://hexdocs.pm/smart_indentation_engine)

A custom EEx engine that does its best to handle indentation in an intuitive
way, so that you can enjoy both clean readable templates and well-formatted
output.

## Features

The engine ships with the following features:

* **Smart Indentation** - Preserves proper indentation in template output.
* **Template Inclusion** - Supports including (and re-indenting) partial
  templates.
* **Assigns Binding** - Access values from the `assigns` binding using the `@`
  syntax (e.g., `@foo`).
* **Flexible Spacing** - Works with both spaces and tabs.

## Overview

This engine extends the default [`EEx.SmartEngine`][hexdocs.eex.smart_engine] by
implementing the `<%|` tag to handles indentation in template blocks.

When you use it with control flow structures like `if`, `for`, `case`, etc., the
the engine automatically aligns the output to match the indentation of the
control statement.

Templates included with `<%= include :template %>` are also re-indented to match
the surrounding context.

## Usage

### Installation

```elixir
def deps do
  [
    {:smart_indentation_engine, "~> 0.1"}
  ]
end
```

### Quick Example

Using the `<%|` tag for control flow:

```elixir
Mix.install([
  {:smart_indentation_engine, "~> 0.1"}
])

"""
<ul>
  <%| for name <- ["world", "darkness my old friend"] do %>
    <li>hello <%= name %></li>
  <% end %>
</ul>
"""
|> EEx.eval_string([], engine: SmartIndentationEngine)
```

Will produce the following output:

```html
<ul>
  <li>hello world</li>
  <li>hello darkness my old friend</li>
</ul>

```

### The `~TT` Sigil

By importing the `SmartIndentationEngine.Template` module you'll have access to
the `~TT` sigil that automatically uses the engine:

```elixir
defmodule Template.BasicList do
  import SmartIndentationEngine.Template

  def render(_assigns \\ []) do
    ~TT"""
    <ul>
      <%| for name <- ["world", "darkness my old friend"] do %>
        <li>hello <%= name %></li>
      <% end %>
    </ul>
    """
  end
end

Template.BasicList.render()
```

### Using `@` for Assigns

```elixir
defmodule Template.AssignedList do
  import SmartIndentationEngine.Template

  def render(assigns \\ []) do
    ~TT"""
    <ul>
      <%| for name <- @names do %>
        <li>hello <%= name %></li>
      <% end %>
    </ul>
    """
  end
end

Template.AssignedList.render(names: ["world", "darkness my old friend"])
```

### Template Inclusion

You can also include other templates using the `include` function. Included
templates will be reindented to match the surrounding context.

```elixir
defmodule Template.IncludedList do
  import SmartIndentationEngine.Template

  def render(assigns \\ []) do
    ~TT"""
    <div>
      <h1>Nice to meet you, hope you guess my name!</h1>
      <%= include :list, names: @names %>
    </div>
    """
  end

  def list(assigns) do
    ~TT"""
    <ul>
      <%| for name <- @names do %>
        <li>hello <%= name %></li>
      <% end %>
    </ul>
    """
  end
end

Template.IncludedList.render(names: ["world", "darkness my old friend"])
```

This produces:

```html
<div>
  <h1>Nice to meet you, hope you guess my name!</h1>
  <ul>
    <li>hello world</li>
    <li>hello darkness my old friend</li>
  </ul>
</div>
```

## How It Works

When you use the `<%|` marker with control structures, the engine:

1. Captures the indentation context of the control statement
2. Remove the empty lines introduced by the control statement
2. Processes the content inside the block (handles nested structures and
   re-indents included templates)
3. Dedents the block output to match captured indentation

## License

The package is available as open source under the terms of the MIT License.

[hexdocs.eex.smart_engine]: https://hexdocs.pm/eex/EEx.SmartEngine.html
