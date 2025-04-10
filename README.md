# SmartIndentationEngine

[![Build Status](https://github.com/goodtouch/smart_indentation_engine/workflows/CI/badge.svg)](https://github.com/goodtouch/smart_indentation_engine/actions/workflows/ci.yml)

A custom EEx engine that does its best to manage indentation so that you can
enjoy both readable templates and properly formatted output.

## Features

The engine ships with the following features:

- **Smart Indentation**: Preserves proper indentation in template output.
- **Template Inclusion**: Supports including (and re-indenting) partial
  templates.
- **Assigns Binding**: Access values from the `assigns` binding using the `@`
  syntax (e.g., `@foo`).
- **Flexible Spacing**: Works with both spaces and tabs.

## Overview

This engine extends the standard EEx engine by implementing the `<%|` tag to
handles indentation in template blocks.

When you use it with control flow structures like `if`, `for`, `case`, etc., the
the engine automatically aligns the output to match the indentation of the
control statement.

Included templates are also re-indented to match the surrounding context.

## Usage

### Installation

```elixir
def deps do
  [
    {:smart_indentation_engine, "~> 0.1.0"}
  ]
end
```

### Basic Example

Using the `<%|` tag for control flow:

```elixir
"""
<ul>
  <%| for item <- [1, 2] do %>
    <li>Item: <%= item %></li>
  <% end %>
</ul>
"""
|> EEx.eval_string([], engine: SmartIndentationEngine)
```

Will produce the following output:

```html
<ul>
  <li>Item: 1</li>
  <li>Item: 2</li>
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
      <%| for item <- [1, 2] do %>
        <li>Item: <%= item %></li>
      <% end %>
    </ul>
    """
  end
end

Template.BasicList.render()
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
      <h1>The List</h1>
      <%= include :list, items: [1, 2] %>
    </div>
    """
  end

  def list(assigns) do
    ~TT"""
    <ul>
      <%| for item <- @items do %>
        <li>Item: <%= item %></li>
      <% end %>
    </ul>
    """
  end
end

Template.IncludedList.render()
```

This produces:

```html
<div>
  <h1>The List</h1>
  <ul>
    <li>Item: 1</li>
    <li>Item: 2</li>
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
