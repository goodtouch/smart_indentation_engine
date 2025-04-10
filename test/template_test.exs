defmodule TemplateTest do
  use ExUnit.Case, async: true

  import SmartIndentationEngine.Template

  test "sigil_TT works with basic template" do
    result = ~TT"""
    Hello world
    """

    assert result == "Hello world"
  end

  test "sigil_TT trims last \n whitespace" do
    result = ~TT"""
    Hello world

    """

    assert result == "Hello world\n"
  end

  def partial(_assigns) do
    ~TT"""
    line 1 from partial
    line 2 from partial
    """
  end

  test "include indents partials" do
    assigns = []

    template = ~TT"""
    before
      <%= include :partial %>
    after
    """

    expected = ~TT"""
    before
      line 1 from partial
      line 2 from partial
    after
    """

    assert_eval(expected, template)
  end

  test "included template within pipe block" do
    assigns = []

    template = ~TT"""
    before
      <%| if true do %>
        <%= include :partial %>
      <% end %>
    after
    """

    expected = ~TT"""
    before
      line 1 from partial
      line 2 from partial
    after
    """

    assert_eval(expected, template)
  end

  def partial_with_partial(assigns) do
    ~TT"""
    line 1 from partial_with_partial
      <%= include :partial %>
    line 3 from partial_with_partial
    """
  end

  test "nested included templates within pipe block" do
    assigns = []

    template = ~TT"""
    before
      <%| if true do %>
        <%= include :partial_with_partial %>
      <% end %>
    after
    """

    expected = ~TT"""
    before
      line 1 from partial_with_partial
        line 1 from partial
        line 2 from partial
      line 3 from partial_with_partial
    after
    """

    assert_eval(expected, template)
  end

  def partial_with_conditional_partial(assigns) do
    ~TT"""
    line 1 from partial_with_partial
      <%| if @condition do %>
        <%= include :partial %>
      <% end %>
    line 3 from partial_with_partial
    """
  end

  test "nested included templates within nested pipe block" do
    assigns = [condition: true]

    template = ~TT"""
    before
      <%| if true do %>
        <%= include :partial_with_conditional_partial %>
      <% end %>
    after
    """

    expected = ~TT"""
    before
      line 1 from partial_with_partial
        line 1 from partial
        line 2 from partial
      line 3 from partial_with_partial
    after
    """

    assert_eval(expected, template)
  end

  test "nested included templates within nested false block" do
    assigns = [condition: false]

    template = ~TT"""
    before
      <%| if true do %>
        <%= include :partial_with_conditional_partial %>
      <% end %>
    after
    """

    expected = ~TT"""
    before
      line 1 from partial_with_partial
      line 3 from partial_with_partial
    after
    """

    assert_eval(expected, template)
  end

  def hello_fr(assigns) do
    ~TT(Bonjour <%= @name %>)
  end

  def hello_en(assigns) do
    ~TT(Hello <%= @name %>)
  end

  test "included templates within case block" do
    assigns = [lang: :fr, name: "John"]

    template = ~TT"""
    <%| case @lang do %>
      <% :fr -> %>
        <%= include :hello_fr %>
      <% _ -> %>
        <%= include :hello_en %>
    <% end %>
    """

    expected = "Bonjour John"

    assert_eval(expected, template)
  end

  defp assert_eval(expected, actual, binding \\ []) do
    result = EEx.eval_string(actual, binding, file: __ENV__.file, engine: SmartIndentationEngine)
    assert result == expected
  end
end
