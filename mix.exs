defmodule SmartIndentationEngine.MixProject do
  use Mix.Project

  # ⚠️ some `./scripts` depends on @version and @github_url being defined here
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
      docs: &docs/0,
      # Use ExCoveralls for test coverage
      test_coverage: [tool: ExCoveralls],
      # Specify which environments commands should run in
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ]
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
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:makeup_html, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @github_url,
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Jean-Paul Bonnetouche"],
      files: ~w(lib mix.exs .formatter.exs CHANGELOG.md LICENSE.md README.md),
      links: %{
        "GitHub" => @github_url,
        "Changelog" => "https://hexdocs.pm/smart_indentation_engine/changelog.html"
      }
    ]
  end
end
