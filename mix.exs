defmodule SmartIndentationEngine.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/goodtouch/smart_indentation_engine"

  @description """
  A custom EEx engine that helps you get both readable templates and properly
  formatted output.
  """

  def project do
    [
      app: :smart_indentation_engine,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "SmartIndentationEngine",
      description: @description,
      source_url: @github_url,
      docs: &docs/0
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @github_url
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Jean-Paul Bonnetouche"],
      files: ~w(lib LICENSE.md mix.exs README.md),
      links: %{
        "GitHub" => @github_url
      }
    ]
  end
end
