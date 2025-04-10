defmodule SmartIndentationEngineTest do
  use ExUnit.Case, async: true

  test "evaluates simple string" do
    assert_eval("foo bar", "foo bar")
  end

  test "evaluates with assigns as keywords" do
    assert_eval("1", "<%= @foo %>", assigns: [foo: 1])
  end

  test "evaluates with assigns as a map" do
    assert_eval("1", "<%= @foo %>", assigns: %{foo: 1})
  end

  test "error with missing assigns" do
    stderr =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        assert_eval("", "<%= @foo %>", assigns: %{})
      end)

    assert stderr =~ "assign @foo not available in EEx template"
  end

  test "evaluates with loops" do
    assert_eval("1\n2\n3\n", "<%= for x <- [1, 2, 3] do %><%= x %>\n<% end %>")
  end

  test "preserves line numbers in assignments" do
    result = EEx.compile_string("foo\n<%= @hello %>", engine: EEx.SmartEngine)

    Macro.prewalk(result, fn
      {_left, meta, [_, :hello]} ->
        assert Keyword.get(meta, :line) == 2
        send(self(), :found)

      node ->
        node
    end)

    assert_received :found
  end

  test "pipe marker with if statement - removes indentation" do
    template = """
    before
      <%| if true do %>
        This should have one level of indentation
          This should have two levels of indentation
      <% end %>
    after
    """

    expected = """
    before
      This should have one level of indentation
        This should have two levels of indentation
    after
    """

    assert_eval(expected, template)
  end

  test "pipe marker with for loop - preserves internal structure" do
    template = """
    <div>
      <%| for item <- [1, 2] do %>
        <p>Item: <%= item %></p>
      <% end %>
    </div>
    """

    expected = """
    <div>
      <p>Item: 1</p>
      <p>Item: 2</p>
    </div>
    """

    assert_eval(expected, template)
  end

  test "pipe marker with case statement - removes indentation" do
    template = """
    <section>
      <%| case "test" do %>
        <% "test" -> %>
          <p>It's a test</p>
        <% other -> %>
          <p>Got: <%= other %></p>
      <% end %>
    </section>
    """

    expected = """
    <section>
      <p>It's a test</p>
    </section>
    """

    assert_eval(expected, template)
  end

  test "pipe marker with cond statement" do
    template = """
    <div>
      <%| cond do %>
        <% true -> %>
          <p>Condition was true</p>
        <% false -> %>
          <p>Condition was false</p>
      <% end %>
    </div>
    """

    expected = """
    <div>
      <p>Condition was true</p>
    </div>
    """

    assert_eval(expected, template)
  end

  test "pipe marker with nested structures" do
    template = """
    <div>
      <%| if true do %>
        <header>
          <%| for x <- [1, 2] do %>
            <span><%= x %></span>
          <% end %>
        </header>
      <% end %>
    </div>
    """

    expected = """
    <div>
      <header>
        <span>1</span>
        <span>2</span>
      </header>
    </div>
    """

    assert_eval(expected, template)
  end

  test "pipe marker with tabs instead of spaces" do
    template = """
    <div>
    \t<%| if true do %>
    \t\t<p>This should be indented with one tab</p>
    \t<% end %>
    </div>
    """

    expected = """
    <div>
    \t<p>This should be indented with one tab</p>
    </div>
    """

    assert_eval(expected, template)
  end

  test "multiple pipe markers at different indentation levels" do
    template = """
    <section>
      <%| if true do %>
        <div>Level 1</div>
        <%| if true do %>
          <div>Level 2</div>
          <%| if true do %>
            <div>Level 3</div>
          <% end %>
        <% end %>
      <% end %>
    </section>
    """

    expected = """
    <section>
      <div>Level 1</div>
      <div>Level 2</div>
      <div>Level 3</div>
    </section>
    """

    assert_eval(expected, template)
  end

  test "pipe marker with 4 spaces" do
    template = """
    <ul>
        <%| for item <- ["a", "b"] do %>
            <li><%= item %></li>
        <% end %>
    </ul>
    """

    expected = """
    <ul>
        <li>a</li>
        <li>b</li>
    </ul>
    """

    assert_eval(expected, template)
  end

  defp assert_eval(expected, actual, binding \\ []) do
    result = EEx.eval_string(actual, binding, file: __ENV__.file, engine: SmartIndentationEngine)
    assert result == expected
  end
end
